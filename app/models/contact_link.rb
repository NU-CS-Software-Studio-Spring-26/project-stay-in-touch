class ContactLink < ApplicationRecord
  belongs_to :requester_person, class_name: "Person"
  belongs_to :recipient_person, class_name: "Person"

  enum :status, { pending: 0, accepted: 1, declined: 2 }

  validate :persons_belong_to_different_users
  validate :persons_not_already_linked, on: :create

  def other_person(person)
    person.id == requester_person_id ? recipient_person : requester_person
  end

  private

  def persons_belong_to_different_users
    return if requester_person.nil? || recipient_person.nil?
    if requester_person.user_id == recipient_person.user_id
      errors.add(:base, "cannot link two contacts belonging to the same user")
    end
  end

  def persons_not_already_linked
    return if requester_person.nil? || recipient_person.nil?
    if requester_person.contact_link.present?
      errors.add(:base, "#{requester_person.name} is already in a shared contact link")
    end
    if recipient_person.contact_link.present?
      errors.add(:base, "#{recipient_person.name} is already in a shared contact link")
    end
  end
end
