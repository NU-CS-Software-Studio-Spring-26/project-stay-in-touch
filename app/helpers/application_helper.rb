module ApplicationHelper
  include Pagy::Frontend
  # Map Rails flash types to Bootstrap contextual classes.
  def flash_bootstrap_class(flash_type)
    case flash_type.to_s
    when "notice", "success" then "success"
    when "alert", "error"    then "danger"
    when "warning"           then "warning"
    else                          "info"
    end
  end

  # Bootstrap badge color for an Event medium.
  def medium_badge_class(medium)
    case medium
    when "call"      then "badge-medium-call"
    when "video"     then "badge-medium-video"
    when "coffee"    then "badge-medium-coffee"
    when "text"      then "badge-medium-text"
    when "in_person" then "badge-medium-in-person"
    else                  "badge-medium-other"
    end
  end

  def highlight_match(text, query)
    return ERB::Util.html_escape(text) if query.blank?
    escaped = ERB::Util.html_escape(text)
    escaped.gsub(/#{Regexp.escape(ERB::Util.html_escape(query))}/i) do |match|
      "<span class=\"search-highlight\">#{match}</span>"
    end.html_safe
  end

  def days_until_due_badge(days)
    return ["No events yet", "badge-none"]     if days.nil?
    return ["Due today",     "badge-due-today"] if days.zero?
    return ["#{days.abs}d overdue", "badge-overdue"] if days.negative?

    ["Due in #{days}d", "badge-upcoming"]
  end

  def snoozed_badge(person)
    return nil unless person.snoozed?

    ["Snoozed until #{person.snoozed_until.strftime("%b %-d")}", "badge-snoozed"]
  end

  # Inline replacement for the abandoned gravatar_image_tag gem (which calls
  # URI.escape, removed in Ruby 3+). Matches the same call shape used in
  # _person_row.html.erb: positional email + an optional gravatar: { size:,
  # default: } hash, plus pass-through HTML options (class:, style:, alt:, ...).
  def gravatar_image_tag(email, **options)
    gravatar_opts = options.delete(:gravatar) || {}
    size    = gravatar_opts[:size]    || 80
    default = gravatar_opts[:default] || "identicon"

    hash = Digest::MD5.hexdigest(email.to_s.strip.downcase)
    url  = "https://www.gravatar.com/avatar/#{hash}?s=#{size}&d=#{CGI.escape(default.to_s)}"

    image_tag(url, **options)
  end
end
