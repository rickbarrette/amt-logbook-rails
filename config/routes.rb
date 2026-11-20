Rails.application.routes.draw do
  resource :session do
    get :two_factor
    post :two_factor, action: :verify_two_factor
  end
  resources :passwords, param: :token
  # Single sign-on: POST /auth/oidc (OmniAuth) comes back here.
  match "auth/:provider/callback", to: "sso#callback", via: %i[get post], as: :sso_callback
  get "auth/failure", to: "sso#failure"
  delete "profile/sso", to: "sso#destroy", as: :sso_link
  resource :about, only: :show
  resource :setup, only: %i[new create], controller: "setup"
  get "invitations/:token", to: "invitations#show", as: :invitation
  patch "invitations/:token", to: "invitations#update"

  resource :two_factor, only: %i[new create destroy] do
    post :recovery_codes
  end
  resource :profile, only: %i[show update] do
    patch :password
    delete :other_sessions
  end
  resources :certificates, only: %i[create destroy]

  scope "suggestions", controller: "suggestions", as: "suggestions" do
    get :entry
    get :locations
    get :aircraft
  end
  resource :markdown_preview, only: :create
  resources :imports, only: %i[index create show update destroy] do
    member do
      post :undo
      post :finish
    end
  end
  resources :work_entries do
    post :submit, on: :member
  end
  resources :timers, only: %i[index create update destroy] do
    member do
      post :pause
      post :resume
      post :stop
    end
  end
  resources :aircraft, only: %i[index show update] do
    get :lookup, on: :collection
    post :refresh, on: :member
  end
  resources :signatures, only: %i[index create] do
    post :return_entry, on: :member
  end
  resource :report, only: :show
  resource :logbook, only: :show do
    get :export
  end

  namespace :admin do
    resources :users, only: %i[index edit update] do
      member do
        post :disable
        post :enable
        post :reset_two_factor
        post :password_reset_link
      end
      resources :supervisions, only: :create
    end
    resources :supervisions, only: :destroy
    resources :invitations, only: %i[new create show destroy]
    resources :registry_imports, only: %i[index create] do
      post :refresh_aircraft, on: :collection
    end
    resource :settings, only: %i[show update]
    resource :airports, only: %i[show create]
    resource :backup, only: %i[show create]
  end

  get "up" => "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "offline" => "offline#show"

  root "dashboard#show"
end
