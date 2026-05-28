module Matchmaking
  # Patient retry wrapper for OpenRouter chat calls. The free Gemma model is
  # rate-limited upstream, but matchmaking is an occasional batch over opted-in
  # users, so we can afford to wait and retry rather than drop a round.
  #
  # Retries ONLY on HTTP 429: it backs off (honoring a Retry-After header when the
  # provider sends one, otherwise growing exponentially up to a cap), then
  # re-raises once attempts are exhausted so callers keep their fail-safe behavior
  # (the pitch secretary returns nil, the review secretary declines).
  module RateLimitedChat
    MAX_ATTEMPTS = 6   # up to ~2 min of patience per call before giving up
    BASE_DELAY   = 5   # seconds, before exponential growth
    MAX_DELAY    = 60  # cap on any single wait

    # Runs the block (an OpenRouter chat call) and returns its value, retrying on
    # 429. Any other error propagates immediately to the caller's own handling.
    def self.with_retry
      attempt = 0
      begin
        yield
      rescue Faraday::TooManyRequestsError => e
        attempt += 1
        if attempt >= MAX_ATTEMPTS
          Rails.logger.error(
            "Matchmaking: OpenRouter 429 retries exhausted after " \
            "#{MAX_ATTEMPTS} attempts; re-raising"
          )
          raise
        end

        delay = retry_after(e) || [ BASE_DELAY * (2**(attempt - 1)), MAX_DELAY ].min
        Rails.logger.info(
          "Matchmaking: OpenRouter 429; attempt #{attempt}/#{MAX_ATTEMPTS}, waiting #{delay}s"
        )
        pause(delay)
        retry
      end
    end

    # OpenRouter / the upstream provider may tell us exactly how long to wait.
    def self.retry_after(error)
      response = error.response if error.respond_to?(:response)
      headers  = response && response[:headers]
      raw      = headers && (headers["retry-after"] || headers["Retry-After"])
      raw.present? ? raw.to_i.clamp(1, MAX_DELAY) : nil
    end

    # Wrapped so specs can stub the wait instead of really sleeping.
    def self.pause(seconds)
      sleep(seconds)
    end
  end
end
