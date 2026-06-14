module Api
  module V1
    class AuthController < ApplicationController
      def register
        user = Identity::User.new(name: params[:name], email: params[:email], password: params[:password])
        if user.save
          token = Identity::Api.encode_token({ user_id: user.id })
          render json: { token: token }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def login
        user = Identity::User.find_by(email: params[:email])
        if user&.authenticate(params[:password])
          token = Identity::Api.encode_token({ user_id: user.id })
          render json: { token: token, user_id: user.id }, status: :ok
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      def logout
        render json: {}, status: :ok
      end
    end
  end
end
