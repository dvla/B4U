module B4U
  class LinterRunner
    def initialize(config:, action:, quiet: false)
      @config = config
      @action = action
      @quiet = quiet
    end

    def run
      check_config
      setup_conditions
      build_linters
      results = execute
      report(results)
    end

  private

    def check_config
      linters = @config['linters'] or raise ConfigError, 'Linters are missing config'
      raise ConfigError, 'All linters must have a name and command' if linters.any? { |l| l['name'].nil? || l['command'].nil? }

      run_if_ids = linters.filter_map { |l| l['run_if'] }.uniq
      return if run_if_ids.empty?

      known_ids = @config['conditions']&.keys || raise(ConfigError, 'Linters have conditional dependencies but no conditions have been declared')
      unknown_ids = run_if_ids - known_ids
      raise ConfigError, "Unknown run_if condition(s): #{unknown_ids.join(', ')}" if unknown_ids.any?
    end

    def setup_conditions
      @conditions = Condition.from_config(@config['conditions'])
      return if @conditions.empty?

      puts 'Running pre-condition checks...'.cyan
      @met = Condition.check(@conditions, @config['linters'])
      @met.each do |id, result|
        condition = @conditions[id]
        if result
          puts "  #{condition.label}: met".green
        else
          puts "  #{condition.label}: unmet".yellow
        end
      end
      puts
    end

    def build_linters
      @linters = @config['linters'].map do |l|
        skip_reason = @conditions[l['run_if']]&.label if l['run_if'] && @met[l['run_if']] != true
        Linter.new(name: l['name'], command: l['command'], ignore: l.fetch('ignore', false), skip_reason:)
      end
    end

    def execute
      skipped_count = @linters.count(&:skip_reason)
      puts "Running #{@linters.size - skipped_count} lint tasks (B4U #{@action})".cyan

      skipped = @linters.select(&:skip_reason).map { |l| [l.name, :skipped, nil] }
      threads = @linters.reject(&:skip_reason).map do |linter|
        Thread.new do
          [linter.name, linter.run, nil]
        rescue LinterError => e
          [linter.name, :failed, e]
        end
      end
      skipped + threads.map { |t| t.join.value }
    end

    def report(results)
      errors = results.filter_map { |_, _, e| e }
      skipped_count = results.count { |_, status, _| status == :skipped }
      skip_reasons = @linters.each_with_object({}) { |l, h| h[l.name] = l.skip_reason if l.skip_reason }

      results.each do |name, status, _|
        if status == :skipped
          puts "🦘 - #{name} (skipped: #{skip_reasons[name]})".yellow
          next
        end

        case status
        when :passed  then puts "✅ - #{name}".green
        when :ignored then puts "⚠️  - #{name} (failed but ignored)".yellow
        when :failed  then puts "❌ - #{name}".red
        else               raise "Unexpected status: #{status}"
        end
      end

      unless errors.empty?
        unless @quiet
          puts
          puts '─' * 60
          errors.each do |error|
            puts " #{error.linter} output:".bold
            puts '─' * 60
            puts error.console_output.red
            puts '─' * 60
          end
        end
        puts "#{@action} prevented because the following linters failed: #{errors.map(&:linter).join(', ')}".red
        exit 1
      end

      summary = 'All linters passed!'
      summary += " (#{skipped_count} skipped)" unless skipped_count.zero?
      puts summary.green
    end
  end
end
