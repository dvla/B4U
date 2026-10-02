# frozen_string_literal: true

require 'fileutils'

# TODO add spec tests
RSpec.describe B4U do
  # Heads up, DO NOT pass rspec as a lint task else it will recursively run this test
  dummy_config = { 'required-files' => nil, 'linters' => [{ 'name' => 'echo', 'command' => 'echo "Hello world"' }] }.freeze
  missing_file_config = { 'required-files' => ['missing_file.rb'], 'linters' => [{ 'name' => 'echo', 'command' => 'echo "Hello world"' }] }.freeze
  failing_linter_config = { 'required-files' => nil, 'linters' => [{ 'name' => 'echo', 'command' => 'exit 1' }] }.freeze

  it 'has a version number' do
    expect(B4U::VERSION).not_to be nil
  end

  it 'throws an error if required files are missing' do
    expect { B4U.lint(config: missing_file_config) }.to raise_error(StructureError)
  end

  it 'can run a successful lint task' do
    expect(B4U.lint(config: dummy_config)).to be nil
  end

  it 'can run a failing link task' do
    expect { B4U.lint(config: failing_linter_config) }.to raise_error(SystemExit)
  end

  describe 'conditions' do
    tmp_dir = File.expand_path('tmp', __dir__)
    sentinel = File.join(tmp_dir, 'ran')

    before { FileUtils.mkdir_p(tmp_dir) }
    after { FileUtils.rm_rf(tmp_dir) }

    conditions = {
      'always' => { 'command' => 'true' },
      'never' => { 'command' => 'false', 'description' => 'never met' },
      'broken' => { 'command' => 'b4u_no_such_command' },
    }.freeze

    def config(conditions, *linters)
      { 'required-files' => nil, 'conditions' => conditions, 'linters' => linters }
    end

    it 'skips linters whose condition is not met, without running them' do
      skipped = { 'name' => 'skipped', 'command' => "touch '#{sentinel}'; exit 1", 'run_if' => 'never' }
      passing = { 'name' => 'passing', 'command' => 'true', 'run_if' => 'always' }
      expect { B4U.lint(config: config(conditions, skipped, passing)) }
        .to output(/🦘 - skipped \(skipped: never met\).*✅ - passing.*All linters passed! \(1 skipped\)/m).to_stdout
      expect(File).not_to exist(sentinel)
    end

    it 'keeps the original summary when nothing is skipped' do
      expect { B4U.lint(config: dummy_config) }.to output(/All linters passed!\n\z/).to_stdout
    end

    it 'still fails when another linter fails' do
      skipped = { 'name' => 'skipped', 'command' => 'true', 'run_if' => 'never' }
      failing = { 'name' => 'failing', 'command' => 'exit 1' }
      expect { B4U.lint(config: config(conditions, skipped, failing)) }
        .to raise_error(SystemExit).and output.to_stdout
    end

    it 'stops before any linter runs when a condition is broken or unknown' do
      first = { 'name' => 'first', 'command' => "touch '#{sentinel}'" }
      %w[broken missing].each do |id|
        bad = { 'name' => 'bad', 'command' => 'true', 'run_if' => id }
        expect { B4U.lint(config: config(conditions, first, bad)) }
          .to raise_error(ConfigError).and output.to_stdout
      end
      expect(File).not_to exist(sentinel)
    end
  end
end
