# One action on several of a technician's own entries at once (Entries list →
# tick entries → choose an action). Each entry follows the same rules as
# doing it by hand: signed entries and ones waiting for a signature aren't
# changed, an entry with its clock still running isn't sent or recorded, and
# an entry that wouldn't pass validation is skipped. The result says what was
# done and why anything was skipped.
class EntryBulkAction
  ACTIONS = {
    "record" => "Record",
    "submit" => "Send for signature",
    "supervisor" => "Set supervisor",
    "fields" => "Edit fields",
    "delete" => "Delete"
  }.freeze

  Result = Data.define(:action, :done, :skipped) do
    def notice
      verb = { "record" => "Recorded", "submit" => "Sent", "supervisor" => "Updated", "fields" => "Updated", "delete" => "Deleted" }[action]
      parts = [ "#{verb} #{done} #{"entry".pluralize(done)}." ]
      if skipped.any?
        parts << "Skipped #{skipped.values.sum}: #{skipped.map { |reason, n| "#{n} #{reason}" }.join(", ")}."
      end
      parts.join(" ")
    end
  end

  def initialize(user, entries, action, params = {})
    @user = user
    @entries = entries
    @action = action.to_s
    @params = params.to_h.with_indifferent_access
  end

  def call
    raise ArgumentError, "unknown action" unless ACTIONS.key?(@action)
    done = 0
    skipped = Hash.new(0)
    error = setup_error
    WorkEntry.transaction do
      @entries.each do |entry|
        reason = error || skip_reason(entry) || perform(entry)
        reason ? skipped[reason] += 1 : done += 1
      end
    end
    Result.new(action: @action, done:, skipped:)
  end

  private

  # A problem with the request itself, applied to every entry.
  def setup_error
    case @action
    when "record" then "not in ink-signature mode" unless Setting.ink_signatures?
    when "submit"
      return "supervisors sign in ink here (use Record)" if Setting.ink_signatures?
      "no supervisor chosen" unless supervisor
    when "supervisor"
      if Setting.ink_signatures?
        "no supervisor name or certificate given" if @params[:supervisor_name].blank? && @params[:supervisor_certificate].blank?
      else
        "no supervisor chosen" unless supervisor
      end
    when "fields" then "nothing to change" if field_changes.empty? && added_areas.empty?
    end
  end

  def skip_reason(entry)
    return "signed" if entry.signed?
    return "waiting for a signature" if entry.submitted?
    return "timer still running" if entry.clocking? && @action != "fields" && @action != "supervisor"
    "already recorded" if @action == "record" && entry.recorded?
  end

  # Nil when done; otherwise why not.
  def perform(entry)
    case @action
    when "record" then entry.record!
    when "submit" then entry.submit!(to: supervisor)
    when "supervisor"
      if Setting.ink_signatures?
        attrs = { supervisor_name: @params[:supervisor_name], supervisor_certificate: @params[:supervisor_certificate] }.compact_blank
        entry.update!(attrs)
      else
        entry.update!(supervisor: supervisor)
      end
    when "fields"
      entry.assign_attributes(field_changes)
      entry.subject_areas = (entry.subject_areas + added_areas).uniq if added_areas.any?
      entry.save!
    when "delete" then entry.destroy!
    end
    nil
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotDestroyed, ArgumentError
    "didn't pass checks (open it to fix)"
  end

  def supervisor
    return @supervisor if defined?(@supervisor)
    @supervisor = @user.supervisors.find_by(id: @params[:supervisor_id])
  end

  def field_changes
    @field_changes ||= {
      category: (@params[:category] if Faa.categories.key?(@params[:category])),
      ata_chapter: (@params[:ata_chapter] if Faa.ata_chapters.key?(@params[:ata_chapter])),
      location: @params[:location].to_s.strip.presence,
      reference: @params[:reference].to_s.strip.presence
    }.compact
  end

  def added_areas = @added_areas ||= Array(@params[:add_subject_area]).compact_blank & Faa.subject_areas.keys
end
