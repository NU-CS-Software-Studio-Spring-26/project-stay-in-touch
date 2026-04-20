# Join model connecting People to Events. Kept as an explicit AR model (rather
# than has_and_belongs_to_many) so future roadmap fields like rsvp_status,
# role, or was_organizer can be added without another migration-with-move.
class EventParticipant < ApplicationRecord
  belongs_to :person
  belongs_to :event

  validates :person_id, uniqueness: { scope: :event_id }
end
