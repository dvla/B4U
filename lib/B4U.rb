# frozen_string_literal: true

require_relative 'B4U/runner'
require_relative 'B4U/string_methods'
require_relative 'B4U/condition'
require_relative 'B4U/linter'
require_relative 'B4U/version'
require_relative 'B4U/error'


module B4U
  def self.lint(config:, quiet: false, action: nil)
    LinterRunner.new(config:, action:, quiet:).run
  end
end
