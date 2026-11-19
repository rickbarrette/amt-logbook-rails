# One-time code for creating the first admin, printed to the server log at
# boot, so whoever finds a fresh install on the internet can't claim it.
module SetupCode
  PATH = Rails.root.join("storage/setup_code")

  module_function

  def current
    return File.read(PATH).strip if File.exist?(PATH)
    SecureRandom.alphanumeric(10).upcase.tap { |code| FileUtils.mkdir_p(PATH.dirname) && File.write(PATH, code) }
  end

  def valid?(code) = ActiveSupport::SecurityUtils.secure_compare(current, code.to_s.strip.upcase)
  def clear! = FileUtils.rm_f(PATH)
end
