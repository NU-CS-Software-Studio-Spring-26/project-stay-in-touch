module AuthHelpers
  def sign_in(user, password: "Password1!secure")
    post login_path, params: { email: user.email, password: password }
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
