# frozen_string_literal: true

require 'fileutils'

RSpec.describe Condition do
  tmp_dir = File.expand_path('tmp', __dir__)

  before { FileUtils.mkdir_p(tmp_dir) }
  after { FileUtils.rm_rf(tmp_dir) }

  def result_of(command)
    described_class.new(command:).evaluate.first
  end

  describe '#evaluate' do
    it 'is met when the command exits 0 and unmet for any other exit code' do
      expect(result_of('true')).to eq :met
      expect(result_of('exit 3')).to eq :unmet
    end

    it 'supports negation, mirroring "! git diff --staged --quiet"' do
      expect(result_of('! false')).to eq :met
      expect(result_of('! true')).to eq :unmet
    end

    it 'is broken when the command does not exist' do
      result, output = described_class.new(command: 'b4u_no_such_command').evaluate
      expect(result).to eq :broken
      expect(output).not_to be_empty
    end

    it 'runs a script file, and is broken if the script is not executable' do
      script = File.join(tmp_dir, 'condition.sh')
      File.write(script, "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, script)
      expect(result_of(script)).to eq :met

      File.chmod(0o644, script)
      expect(result_of(script)).to eq :broken
    end
  end

  describe '#label' do
    it 'uses the description, falling back to the command' do
      expect(described_class.new(command: 'true', description: 'Ruby staged').label).to eq 'Ruby staged'
      expect(described_class.new(command: 'true').label).to eq 'true'
    end
  end

  describe '.from_config' do
    it 'builds conditions keyed by id' do
      conditions = described_class.from_config('ruby' => { 'command' => 'true', 'description' => 'Ruby staged' })
      expect(conditions['ruby'].label).to eq 'Ruby staged'
    end

    it 'returns no conditions when the section is missing' do
      expect(described_class.from_config(nil)).to eq({})
    end

    it 'rejects a list instead of a mapping' do
      expect { described_class.from_config([{ 'command' => 'true' }]) }.to raise_error(ConfigError)
    end

    it 'rejects a condition without a command' do
      expect { described_class.from_config('ruby' => { 'comand' => 'true' }) }
        .to raise_error(ConfigError, /Condition 'ruby' needs a 'command'/)
    end
  end

  describe '.check' do
    def check(conditions_config, *run_ifs)
      linters = run_ifs.map { |id| { 'name' => 'step', 'command' => 'true', 'run_if' => id } }
      described_class.check(described_class.from_config(conditions_config), linters)
    end

    it 'returns whether each used condition was met' do
      result = check({ 'yes' => { 'command' => 'true' }, 'no' => { 'command' => 'false' } }, 'yes', 'no', nil)
      expect(result).to eq('yes' => true, 'no' => false)
    end

    it 'runs a condition shared by several linters only once' do
      counter = File.join(tmp_dir, 'count')
      check({ 'shared' => { 'command' => "echo x >> '#{counter}'" } }, 'shared', 'shared')
      expect(File.readlines(counter).count).to eq 1
    end

    it 'does not run conditions that no linter uses' do
      expect(check({ 'unused' => { 'command' => 'b4u_no_such_command' } })).to eq({})
    end

    it 'rejects a run_if that names an unknown condition' do
      expect { check({}, 'missing') }.to raise_error(ConfigError, /Unknown run_if condition\(s\): missing/)
    end

    it 'rejects a broken condition, including its output' do
      expect { check({ 'broken' => { 'command' => 'b4u_no_such_command' } }, 'broken') }
        .to raise_error(ConfigError, /Condition 'broken' could not run:\n.+/)
    end
  end
end
