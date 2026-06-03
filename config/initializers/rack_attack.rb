class Rack::Attack
  # ── Safelists ──────────────────────────────────────────────────────────────
  # Never throttle localhost (useful for dev/test; harmless in prod since
  # 127.0.0.1 requests never come from the public internet).
  safelist("allow-localhost") { |req| req.ip == "127.0.0.1" || req.ip == "::1" }

  # ── Signup throttle ────────────────────────────────────────────────────────
  # 5 new accounts per hour per IP stops automated account-farming while
  # remaining invisible to any legitimate user.
  throttle("signups/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.path == "/signup" && req.post?
  end

  # ── Login throttle ─────────────────────────────────────────────────────────
  # 10 attempts per 3 minutes per IP (mirrors the Rails rate_limit in
  # SessionsController but operates at the Rack layer before the app boots).
  throttle("login/ip", limit: 10, period: 3.minutes) do |req|
    req.ip if req.path == "/login" && req.post?
  end

  # Per-email login throttle: 5 failures per 20 seconds per normalised email.
  # This prevents credential-stuffing against a known account even from
  # distributed IPs.
  throttle("login/email", limit: 5, period: 20.seconds) do |req|
    if req.path == "/login" && req.post?
      req.params["email"].to_s.downcase.strip.presence
    end
  end

  # ── Password-reset throttle ────────────────────────────────────────────────
  # 3 reset emails per hour per IP.
  throttle("password_reset/ip", limit: 3, period: 1.hour) do |req|
    req.ip if req.path == "/password_reset" && req.post?
  end

  # ── General request throttle ───────────────────────────────────────────────
  # 300 requests per 5 minutes per IP — a ceiling that stops simple scrapers
  # but is never hit by a normal user.
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/assets")
  end

  # ── Throttled response ─────────────────────────────────────────────────────
  self.throttled_responder = lambda do |req|
    retry_after = (req.env["rack.attack.match_data"] || {})[:period]
    [
      429,
      {
        "Content-Type"  => "text/html",
        "Retry-After"   => retry_after.to_s
      },
      ["<h1>Too many requests</h1><p>Please wait a moment and try again.</p>"]
    ]
  end
end
