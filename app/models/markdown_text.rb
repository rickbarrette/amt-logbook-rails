# Plain text from an entry's Markdown, for the PDF, CSV and short previews:
# list markers become bullets, emphasis and heading marks are dropped.
module MarkdownText
  module_function

  def plain(text)
    text.to_s.lines.map do |line|
      line.sub(/\A(\s*)[-*+]\s+/) { "#{$1}• " }
          .sub(/\A\s*\#{1,6}\s+/, "")
          .gsub(/(\*\*|__)(.+?)\1/, '\2').gsub(/(?<![\w*])[*_](?!\s)(.+?)(?<!\s)[*_](?![\w*])/, '\1')
          .gsub(/`([^`]+)`/, '\1').gsub(/\[([^\]]+)\]\([^)]+\)/, '\1')
    end.join.strip
  end
end
