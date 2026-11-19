# Renders Markdown for the editor's Preview tab, with the same rules and
# sanitizing as saved entries.
class MarkdownPreviewsController < ApplicationController
  def create
    render html: helpers.markdown(params[:text].to_s.first(20_000))
  end
end
