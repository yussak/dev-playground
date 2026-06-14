module Identity
  module JwtHelper
    ALGORITHM = "HS256"
    EXPIRY = 24.hours

    def self.encode(payload)
      payload = payload.merge(exp: EXPIRY.from_now.to_i)
      JWT.encode(payload, Rails.application.secret_key_base, ALGORITHM)
    end

    def self.decode(token)
      decoded = JWT.decode(token, Rails.application.secret_key_base, true, { algorithm: ALGORITHM })
      decoded.first.with_indifferent_access
    rescue JWT::DecodeError
      nil
    end
  end
end
