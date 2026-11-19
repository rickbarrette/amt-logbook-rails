module ApplicationHelper
  STATUS_STYLES = {
    "draft" => "bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-200",
    "submitted" => "bg-amber-100 text-amber-800 dark:bg-amber-900/50 dark:text-amber-200",
    "returned" => "bg-red-100 text-red-800 dark:bg-red-900/50 dark:text-red-200",
    "signed" => "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/50 dark:text-emerald-200",
    "recorded" => "bg-sky-100 text-sky-800 dark:bg-sky-900/50 dark:text-sky-200"
  }.freeze
  STATUS_LABELS = { "draft" => "Draft", "submitted" => "Awaiting signature", "returned" => "Returned", "signed" => "Signed", "recorded" => "Recorded" }.freeze

  # CHANGELOG.md and other trusted Markdown, rendered and sanitized.
  def markdown(text, **opts)
    html = Commonmarker.to_html(text.to_s, options: { render: { unsafe: false, hardbreaks: true } })
    tag.div(sanitize(html), class: "prose-notes #{opts[:class]}")
  end

  def status_badge(status) = tag.span(STATUS_LABELS[status], class: "badge #{STATUS_STYLES[status]}")

  def hours(value) = number_with_precision(value, precision: 1, strip_insignificant_zeros: false)

  def duration(seconds)
    h, rem = seconds.to_i.divmod(3600)
    format("%d:%02d:%02d", h, rem / 60, rem % 60)
  end

  def nav_link(label, path, badge: nil)
    active = current_page?(path) || (path != root_path && request.path.start_with?(path))
    classes = active ? "bg-sky-50 text-sky-800 dark:bg-slate-700 dark:text-white" : "text-slate-600 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-slate-700"
    link_to path, class: "relative rounded-lg px-3 py-2 text-sm font-medium #{classes}" do
      safe_join([ label, (tag.span(badge, class: "ml-1 badge bg-amber-500 text-white") if badge.to_i.positive?) ])
    end
  end

  def progress_bar(percent, color: "bg-sky-600")
    tag.div(class: "h-2.5 w-full overflow-hidden rounded-full bg-slate-200 dark:bg-slate-700") do
      tag.div(class: "h-full rounded-full #{color}", style: "width: #{percent.clamp(0, 100)}%")
    end
  end

  def category_options = Faa.categories.map { |k, v| [ v, k ] }
  def ata_options = Faa.ata_chapters.map { |k, v| [ "#{k} - #{v}", k ] }
  def rating_goal_options = Faa.ratings.map { |k, v| [ v["label"], k ] }
  def certificate_kind_options = Faa.certificate_kinds.map { |k, v| [ v["label"], k ] }

  def field_errors(record, attr)
    return unless record.errors[attr].any?
    tag.p(record.errors.full_messages_for(attr).to_sentence, class: "mt-1 text-sm text-red-600 dark:text-red-400")
  end
end
