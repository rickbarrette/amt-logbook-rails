# What the About page shows: version, build, uptime, configuration (never
# secrets) and the health of the databases and background jobs.
class SystemInfo
  KEY_GEMS = %w[puma thruster propshaft importmap-rails turbo-rails stimulus-rails tailwindcss-rails solid_queue
                solid_cache sqlite3 chartkick prawn rotp omniauth omniauth_openid_connect rubyzip bcrypt].freeze
  REPOSITORY_URL = ENV["APP_REPOSITORY_URL"].presence || "https://github.com/rickbarrette/amt-logbook-rails"
  DATABASES = { "Main" => "primary", "Cache" => "cache", "Job queue" => "queue" }.freeze

  def version = Rails.application.config.x.version
  def revision = Rails.application.config.x.app_revision
  def booted_at = Rails.application.config.x.booted_at

  def repository_url = REPOSITORY_URL.match?(%r{\Ahttps?://[^\s"'<>]+\z}) ? REPOSITORY_URL.chomp("/") : nil
  def revision_url = ("#{repository_url}/commit/#{revision}" if repository_url && revision.match?(/\A\h{7,40}\z/))
  def release_url = ("#{repository_url}/releases/tag/v#{version}" if repository_url && version.match?(/\A\d{4}\.\d+\.\d+\z/))

  def built_at
    Time.zone.parse(ENV["APP_BUILT_AT"].to_s) if ENV["APP_BUILT_AT"].present?
  rescue ArgumentError
    nil
  end

  def runtime
    { "Ruby" => "#{RUBY_VERSION} (#{RUBY_PLATFORM})", "YJIT" => defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? "on" : "off",
      "Rails" => Rails.version, "SQLite" => SQLite3::SQLITE_VERSION, "Environment" => Rails.env, "Time zone" => Time.zone_default.name }
  end

  def features
    last = RegistryRecord.last_import
    { "Signatures" => Setting.ink_signatures? ? "Ink only" : "Electronic and ink",
      "Single sign-on" => Sso.enabled? ? (Sso.password_login? ? Sso.label : "#{Sso.label} only") : "Not configured",
      "Email" => ENV["SMTP_ADDRESS"].present? ? "SMTP (#{ENV["SMTP_ADDRESS"]})" : "Not configured (copy invitation links)",
      "FAA registry" => last ? "#{RegistryRecord.count.to_fs(:delimited)} aircraft, imported #{last.finished_at.to_date.to_fs(:long)}" : "Not imported",
      "HTTPS" => Rails.application.config.force_ssl ? "Yes" : "No",
      "Hours per month (65.77)" => Faa.hours_per_month.round.to_s }
  end

  def key_gems = KEY_GEMS.filter_map { |n| (s = Gem.loaded_specs[n]) && [ n, s.version.to_s ] }
  def all_gems = Gem.loaded_specs.values.sort_by(&:name).map { [ _1.name, _1.version.to_s ] }

  def databases
    DATABASES.filter_map do |label, name|
      config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name:) or next
      path = Rails.root.join(config.database.to_s)
      [ label, path.exist? ? Dir["#{path}*"].sum { File.size(_1) } : nil ]
    end
  end

  def free_disk_bytes
    line = IO.popen([ "df", "-Pk", Rails.root.join("storage").to_s ], err: File::NULL, &:read).lines.last
    line.split[3].to_i * 1024 if line
  rescue SystemCallError
    nil
  end

  def record_counts
    { "Users" => User.count, "Technicians" => User.where(technician: true).count, "Supervisors" => User.where(supervisor: true).count,
      "Entries" => WorkEntry.count, "Signed entries" => WorkEntry.signed.count, "Aircraft" => Aircraft.count, "Running timers" => Timer.running.count }
  end

  def jobs
    return unless defined?(SolidQueue) && SolidQueue::Job.table_exists?
    { workers: SolidQueue::Process.where(last_heartbeat_at: 5.minutes.ago..).count, ready: SolidQueue::ReadyExecution.count,
      scheduled: SolidQueue::ScheduledExecution.count, failed: SolidQueue::FailedExecution.count }
  rescue ActiveRecord::ActiveRecordError
    nil
  end
end
