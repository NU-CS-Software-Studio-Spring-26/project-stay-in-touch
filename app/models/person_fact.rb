class PersonFact < ApplicationRecord
  CATEGORIES = %w[work personal interests life_event other].freeze

  CATEGORY_META = {
    "work"       => { label: "Work",       icon: "bi-briefcase",      css: "bg-primary bg-opacity-10 text-primary" },
    "personal"   => { label: "Personal",   icon: "bi-heart",          css: "bg-danger bg-opacity-10 text-danger" },
    "interests"  => { label: "Interests",  icon: "bi-stars",          css: "bg-warning bg-opacity-10 text-warning" },
    "life_event" => { label: "Life Event", icon: "bi-calendar-event", css: "bg-info bg-opacity-10 text-info" },
    "other"      => { label: "Other",      icon: "bi-tag",            css: "bg-secondary bg-opacity-10 text-secondary" }
  }.freeze

  belongs_to :person

  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :body, presence: true, length: { maximum: 500 }, no_profanity: true

  def meta
    CATEGORY_META.fetch(category, CATEGORY_META["other"])
  end
end
