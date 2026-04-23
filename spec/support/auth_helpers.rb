module AuthHelpers
  def sign_in(user, password: "password12345")
    post login_path, params: { email: user.email, password: password }
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
