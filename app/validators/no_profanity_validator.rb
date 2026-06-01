class NoProfanityValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?
    if Obscenity.profane?(value.to_s)
      record.errors.add(attribute, "contains inappropriate language")
    end
  end
end
