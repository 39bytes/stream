require "oauth2"

ADMINS = [47371088]

class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[login authorized user]

  @@api_url = "https://api.github.com"
  @@auth_url = "https://github.com/login/oauth/authorize"
  @@token_url = "https://github.com/login/oauth/access_token"
  @@oauth_client = OAuth2::Client.new(
    ENV["GITHUB_CLIENT_ID"], ENV["GITHUB_CLIENT_SECRET"],
    site: @@api_url,
    authorize_url: @@auth_url,
    token_url: @@token_url
  )
  @@redirect_uri = ENV["GITHUB_REDIRECT_URI"]

  def user
    render json: resume_session&.user
  end

  def login
    oauth_url = @@oauth_client.auth_code.authorize_url(redirect_uri: @@redirect_uri, scope: "user:email")
    redirect_to oauth_url, allow_other_host: true
  end

  def authorized
    access = @@oauth_client.auth_code.get_token(params[:code], redirect_uri: @@redirect_uri)
    response = access.get("/user")
    data = JSON.parse(response.body)

    User.upsert({
      id: data["id"],
      email: data["email"],
      login: data["login"],
      name: data["name"],
      admin: ADMINS.include?(data["id"])
    })
    user = User.find(data["id"])

    start_new_session_for user
    redirect_to request.headers["Referer"]
  end

  def logout
    terminate_session
    redirect_to request.headers["Referer"]
  end
end
