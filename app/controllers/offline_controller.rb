# Shown by the service worker when the server can't be reached.
class OfflineController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :require_two_factor_setup

  def show
    render layout: false
  end
end
