class Linter
  attr_reader :name, :command, :ignore, :skip_reason

  def initialize(name:, command:, ignore: false, skip_reason: nil)
    @name = name
    @command = command
    @ignore = ignore
    @skip_reason = skip_reason
  end

  def run
    console_output, status = Open3.capture2e(command)
    if status.success?
      :passed
    elsif ignore
      :ignored
    else
      raise LinterError.new(linter: name, console_output:)
    end
  end
end
