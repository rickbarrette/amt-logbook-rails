# "Confirm with a passkey" before signing entries or downloading a backup,
# instead of typing the password and an authenticator code. The
# confirmation lasts a few minutes and is used up by the action.
class PasskeyConfirmationsController < ApplicationController
  rate_limit to: 20, within: 5.minutes, with: -> { render json: { error: "Too many tries. Try again later." }, status: :too_many_requests }

  def options
    return render(json: { error: "You have no passkeys yet." }, status: :unprocessable_entity) if current_user.passkeys.none?
    options = relying_party.options_for_authentication(allow: current_user.passkeys.pluck(:external_id), user_verification: "required")
    store_challenge(:confirmation, options)
    render json: options
  end

  def create
    if verify_passkey_assertion(:confirmation, user: current_user)
      session[:passkey_confirmed_at] = Time.current.to_i
      render json: { reload: true }
    else
      render json: { error: "That passkey didn't confirm it's you. Try again." }, status: :unprocessable_entity
    end
  end
end
