# Join model connecting People to Events. Kept as an explicit AR model (rather
# than has_and_belongs_to_many) so future roadmap fields like rsvp_status,
# role, or was_organizer can be added without another migration-with-move.
#
# Schema (see db/schema.rb for the authoritative version):
#   person_id  :integer not null  (FK -> people.id)
#   event_id   :integer not null  (FK -> events.id)
#   Composite unique index on (person_id, event_id).
class EventParticipant < ApplicationRecord
  belongs_to :person
  belongs_to :event

  validates :person_id, uniqueness: { scope: :event_id }
end
