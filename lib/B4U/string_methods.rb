class String
  class << self
    attr_accessor :colour_enabled
  end

  def self.enable_colour
    self.colour_enabled = true
  end

  def self.disable_colour
    self.colour_enabled = false
  end

  def colorize(code)
    return self unless String.colour_enabled

    "\e[#{code}m#{self}\e[0m"
  end

  def red = colorize(31)

  def green = colorize(32)

  def yellow = colorize(33)

  def magenta = colorize(35)

  def cyan = colorize(36)

  def bg_green = colorize(42)

  def bold = colorize(1)
end
