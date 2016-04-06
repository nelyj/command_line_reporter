require 'stringio'

require 'command_line_reporter/options_validator'
require 'command_line_reporter/formatter/progress'
require 'command_line_reporter/formatter/nested'
require 'command_line_reporter/row'
require 'command_line_reporter/column'
require 'command_line_reporter/table'
require 'command_line_reporter/version'

# rubocop:disable Metrics/ModuleLength
module CommandLineReporter
  include OptionsValidator

  attr_reader :formatter

  DEFAULTS = {
    width: 100,
    align: 'left',
    formatter: 'nested',
    encoding: :unicode
  }.freeze

  def capture_output
    $stdout.rewind
    $stdout.read
  ensure
    $stdout = STDOUT
  end

  def suppress_output
    $stdout = StringIO.new
  end

  def restore_output
    $stdout = STDOUT
  end

  def formatter=(type = 'nested')
    return type if type.class != String
    name = type.capitalize + 'Formatter'
    klass = %W(CommandLineReporter #{name}).inject(Kernel) { |a, e| a.const_get(e) }

    # Each formatter is a singleton that responds to #instance
    @formatter = klass.instance
  rescue
    raise ArgumentError, 'Invalid formatter specified'
  end

  def header(options = {})
    section(:header, options)
  end

  def report(options = {}, &block)
    self.formatter ||= DEFAULTS[:formatter]
    self.formatter.format(options, block)
  end

  def progress(override = nil)
    self.formatter.progress(override)
  end

  def footer(options = {})
    section(:footer, options)
  end

  def horizontal_rule(options = {})
    validate_options(options, :char, :width, :color, :bold)

    # Got unicode?
    use_char = "\u2501" == 'u2501' ? '-' : "\u2501"

    char = options[:char].is_a?(String) ? options[:char] : use_char
    width = options[:width] || DEFAULTS[:width]

    aligned(char * width, width: width, color: options[:color], bold: options[:bold])
  end

  def vertical_spacing(lines = 1)
    lines = Integer(lines)

    # because puts "\n" * 0 produces an unwanted newline
    if lines == 0
      print "\0"
    else
      puts "\n" * lines
    end
  end

  def datetime(options = {})
    validate_options(options, :align, :width, :format, :color, :bold)
    format, align, width = default_datetime_options(options)

    text = Time.now.strftime(format)

    raise Exception if text.size > width

    aligned(text, align: align, width: width, color: options[:color], bold: options[:bold])
  end

  def define_alignment_defaults(options)
    align = options[:align] || DEFAULTS[:align]
    width = options[:width] || DEFAULTS[:width]
    color = options[:color]
    bold = options[:bold] || false
    [align, width, color, bold]
  end

  def aligned(text, options = {})
    validate_options(options, :align, :width, :color, :bold)
    align, width, color, bold = define_alignment_defaults(options)

    # align = options[:align] || DEFAULTS[:align]
    # width = options[:width] || DEFAULTS[:width]
    # color = options[:color]
    # bold = options[:bold] || false

    line = case align
           when 'left'
             text
           when 'right'
             text.rjust(width)
           when 'center'
             text.rjust((width - text.size) / 2 + text.size)
           else
             raise ArgumentError
           end

    line = line.send(color) if color
    line = line.send('bold') if bold

    puts line
  end

  def table(options = {})
    @table = CommandLineReporter::Table.new(options)
    yield
    @table.output
  end

  def row(options = {})
    options[:encoding] ||= @table.encoding
    @row = CommandLineReporter::Row.new(options)
    yield
    @table.add(@row)
  end

  def column(text, options = {})
    col = CommandLineReporter::Column.new(text, options)
    @row.add(col)
  end

  private

  def default_datetime_options(options)
    format = define_format(options)
    align = define_align(options)
    width = define_width(options)
    [format, align, width]
  end

  def define_width(options)
    options[:width] || DEFAULTS[:width]
  end

  def define_format(options)
    options[:format] || '%Y-%m-%d - %l:%M:%S%p'
  end

  def define_align(options)
    align = options[:align] || DEFAULTS[:align]
  end

  def section(type, options)
    title, width, align, lines, color, bold = assign_section_properties(options)

    # This also ensures that width is a Fixnum
    raise ArgumentError if title.size > width

    if type == :footer
      vertical_spacing(lines)
      horizontal_rule(char: options[:rule], width: width, color: color, bold: bold) if options[:rule]
    end

    aligned(title, align: align, width: width, color: color, bold: bold)
    datetime(align: align, width: width, color: color, bold: bold) if options[:timestamp]

    if type == :header
      horizontal_rule(char: options[:rule], width: width, color: color, bold: bold) if options[:rule]
      vertical_spacing(lines)
    end
  end

  def assign_section_properties(options)
    validate_options(options, :title, :width, :align, :spacing, :timestamp, :rule, :color, :bold)

    title = options[:title] || 'Report'
    width = options[:width] || DEFAULTS[:width]
    align = options[:align] || DEFAULTS[:align]
    lines = options[:spacing] || 1
    color = options[:color]
    bold = options[:bold] || false

    [title, width, align, lines, color, bold]
  end
end
