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

  def days_until_due_badge(days)
    return ["No events yet", "badge-none"]     if days.nil?
    return ["Due today",     "badge-due-today"] if days.zero?
    return ["#{days.abs}d overdue", "badge-overdue"] if days.negative?

    ["Due in #{days}d", "badge-upcoming"]
  end
end
