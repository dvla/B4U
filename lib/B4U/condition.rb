require 'open3'

class Condition
  # 126 = found but not executable, 127 = command not found
  BROKEN_EXIT_CODES = [126, 127].freeze

  attr_reader :command, :description

  def initialize(command:, description: nil)
    @command = command
    @description = description
  end

  # Builds { id => Condition } from the top-level `conditions:` config
  def self.from_config(config)
    return {} if config.nil?
    raise ConfigError, 'conditions must be a mapping of id to condition' unless config.is_a?(Hash)

    config.to_h do |id, condition|
      raise ConfigError, "Condition '#{id}' needs a 'command'" unless condition.is_a?(Hash) && condition['command'].is_a?(String)

      [id, new(command: condition['command'], description: condition['description'])]
    end
  end

  # Runs each condition the linters use once, in parallel. Returns { id => true if met }
  def self.check(conditions, linters)
    ids = linters.filter_map { |linter| linter['run_if'] }.uniq
    unknown_ids = ids - conditions.keys
    raise ConfigError, "Unknown run_if condition(s): #{unknown_ids.join(', ')}" unless unknown_ids.empty?

    threads = ids.to_h { |id| [id, Thread.new { conditions[id].evaluate }] }
    threads.to_h do |id, thread|
      result, console_output = thread.value
      raise ConfigError, "Condition '#{id}' could not run:\n#{console_output}" if result == :broken

      [id, result == :met]
    end
  end

  def label
    description || command
  end

  # Returns [:met | :unmet | :broken, console_output]
  def evaluate
    console_output, status = Open3.capture2e(command)
    if status.success?
      [:met, console_output]
    elsif BROKEN_EXIT_CODES.include?(status.exitstatus)
      [:broken, console_output]
    else
      [:unmet, console_output]
    end
  rescue SystemCallError => e
    [:broken, e.message]
  end
end
