module Identity
  # identity モジュールの公開窓口。外部からはこのクラス経由でのみ呼ぶ。
  class Api
    # JWT を発行する。payload 例: { user_id: 1 }
    def self.encode_token(payload)
      JwtHelper.encode(payload)
    end

    # トークンを検証し、該当ユーザーを返す。無効なら nil。
    def self.authenticate(token)
      payload = JwtHelper.decode(token)
      return nil unless payload

      User.find_by(id: payload[:user_id])
    end
  end
end
