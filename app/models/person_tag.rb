class PersonTag < ApplicationRecord
  belongs_to :person
  belongs_to :tag
end
