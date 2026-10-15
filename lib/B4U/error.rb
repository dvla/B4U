# rubocop:disable Style/OneClassPerFile
class LinterError < StandardError
  attr_reader :linter, :console_output
  def initialize(linter:, console_output:, msg: 'Linter error')
    @linter = linter
    @console_output = console_output
    super(msg)
  end
end

class ConfigError < StandardError
  def initialize(msg = 'Config error')
    super
  end
end
# rubocop:enable Style/OneClassPerFile
