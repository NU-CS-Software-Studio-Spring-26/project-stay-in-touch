module ApplicationHelper
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
    when "call"      then "bg-primary"
    when "video"     then "bg-info text-dark"
    when "coffee"    then "bg-warning text-dark"
    when "text"      then "bg-secondary"
    when "in_person" then "bg-success"
    else                   "bg-dark"
    end
  end

  # Present a "days until due" number in words with a matching Bootstrap badge.
  # Returns `[label, css_class]` so callers can render however they like.
  def days_until_due_badge(days)
    return ["No events yet", "bg-secondary"] if days.nil?
    return ["Due today", "bg-warning text-dark"] if days.zero?
    return ["#{days.abs} days overdue", "bg-danger"] if days.negative?

    ["Due in #{days} days", "bg-success"]
  end
end
