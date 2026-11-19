# CHANGELOG.md split into releases ("## 2026.11.1" headings), so the About
# page can show the running version's notes and fold the older ones.
class Changelog
  PATH = Rails.root.join("CHANGELOG.md")
  Release = Data.define(:version, :markdown) do
    def anchor = "v#{version.tr('.', '-')}"
  end

  def self.load = new(PATH.file? ? PATH.read : "")

  attr_reader :releases

  def initialize(markdown)
    _head, *parts = markdown.split(/^## /)
    @releases = parts.filter_map do |part|
      version, body = part.split("\n", 2)
      Release.new(version: version.strip, markdown: body.to_s.strip) if version.strip.match?(/\A\d{4}\.\d{1,2}\.\d+\z/)
    end
  end

  def release(version) = releases.find { _1.version == version }
end
