class ApplicationController < ActionController::API
  private

  def authenticate_user!
    token = request.headers["Authorization"]&.split(" ")&.last
    @current_user = Identity::Api.authenticate(token)
    render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
  end
end
