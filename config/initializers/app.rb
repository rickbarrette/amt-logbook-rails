# Version (VERSION file, YYYY.MM.N) and build (APP_REVISION, the commit).
Rails.application.config.x.version = Rails.root.join("VERSION").read.strip rescue "dev"
Rails.application.config.x.app_revision = ENV["APP_REVISION"].presence ||
  (`git -C #{Rails.root} rev-parse --short HEAD 2>/dev/null`.strip.presence rescue nil) || "dev"

# Prawn's built-in fonts are Windows-1252; LogbookPdf transliterates text.
Prawn::Fonts::AFM.hide_m17n_warning = true

# Fresh install: print the setup code for the first admin account.
Rails.application.config.after_initialize do
  next unless defined?(Rails::Server)
  if ActiveRecord::Base.connection.data_source_exists?("users") && !User.exists?
    msg = "[setup] Setup code for the first admin account: #{SetupCode.current}"
    Rails.logger.info(msg)
    puts msg
  end
rescue ActiveRecord::ActiveRecordError
  nil
end
