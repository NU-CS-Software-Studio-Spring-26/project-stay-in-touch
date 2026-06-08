# Single gateway for every OpenRouter chat completion in the app. Owning the
# model choice, the client, and the failure handling in ONE place is what keeps
# the model name from being copy-pasted across each AI service.
#
# Models:
#   PRIMARY_MODEL  - paid, reliable; what we use normally.
#   FALLBACK_MODEL - free; used automatically when the paid account runs out of
#                    credit. OpenRouter answers HTTP 402 (Payment Required) when
#                    the balance can't cover a request, so AI features degrade to
#                    the free model instead of failing outright when money runs out.
#
# Also retries on HTTP 429 (rate limit), honoring a Retry-After header, because
# the free model especially is rate-limited upstream and our calls are occasional
# batches we can afford to wait on.
module OpenRouterChat
  PRIMARY_MODEL  = "openai/gpt-4o-mini"
  FALLBACK_MODEL = "google/gemma-4-26b-a4b-it:free"

  URI_BASE = "https://openrouter.ai/api/v1".freeze

  MAX_ATTEMPTS = 6   # up to ~2 min of patience per call before giving up on 429s
  BASE_DELAY   = 5   # seconds, before exponential growth
  MAX_DELAY    = 60  # cap on any single wait

  module_function

  # Runs one chat completion and returns the raw OpenAI-gem response hash.
  # Transparently falls back to the free model on a 402 (out of credit). Errors
  # other than 402/429 propagate to the caller's own handling (each service
  # already rescues and degrades — pitch returns nil, review declines, etc.).
  def completion(messages:, max_tokens:)
    with_retry { chat(PRIMARY_MODEL, messages, max_tokens) }
  rescue Faraday::Error => e
    raise unless out_of_credit?(e)

    Rails.logger.warn(
      "OpenRouterChat: #{PRIMARY_MODEL} returned 402 (out of credit); " \
      "falling back to #{FALLBACK_MODEL}"
    )
    with_retry { chat(FALLBACK_MODEL, messages, max_tokens) }
  end

  def client
    OpenAI::Client.new(access_token: ENV["OPENROUTER_API_KEY"], uri_base: URI_BASE)
  end

  def chat(model, messages, max_tokens)
    client.chat(parameters: { model: model, messages: messages, max_tokens: max_tokens })
  end

  # OpenRouter answers 402 Payment Required when the account can't pay for a call.
  def out_of_credit?(error)
    response = error.respond_to?(:response) ? error.response : nil
    status   = response.is_a?(Hash) ? response[:status] : nil
    status.to_i == 402
  end

  # Patient retry on HTTP 429: backs off (honoring Retry-After when present,
  # otherwise growing exponentially up to a cap), then re-raises once attempts are
  # exhausted so callers keep their fail-safe behavior. Other errors pass straight
  # through (including 402, which #completion handles above).
  def with_retry
    attempt = 0
    begin
      yield
    rescue Faraday::TooManyRequestsError => e
      attempt += 1
      if attempt >= MAX_ATTEMPTS
        Rails.logger.error(
          "OpenRouterChat: 429 retries exhausted after #{MAX_ATTEMPTS} attempts; re-raising"
        )
        raise
      end

      delay = retry_after(e) || [ BASE_DELAY * (2**(attempt - 1)), MAX_DELAY ].min
      Rails.logger.info(
        "OpenRouterChat: 429; attempt #{attempt}/#{MAX_ATTEMPTS}, waiting #{delay}s"
      )
      pause(delay)
      retry
    end
  end

  # OpenRouter / the upstream provider may tell us exactly how long to wait.
  def retry_after(error)
    response = error.respond_to?(:response) ? error.response : nil
    headers  = response.is_a?(Hash) ? response[:headers] : nil
    raw      = headers && (headers["retry-after"] || headers["Retry-After"])
    raw.present? ? raw.to_i.clamp(1, MAX_DELAY) : nil
  end

  # Wrapped so specs can stub the wait instead of really sleeping.
  def pause(seconds)
    sleep(seconds)
  end
end
