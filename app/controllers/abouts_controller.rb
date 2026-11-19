# About: version, build, uptime and release notes for everyone; system
# details (configuration, storage, jobs, components) for admins.
class AboutsController < ApplicationController
  def show
    @info = SystemInfo.new
    @changelog = Changelog.load
  end
end
