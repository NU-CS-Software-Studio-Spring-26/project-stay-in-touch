require "csv"

# Parses CSV or vCard (.vcf) files and bulk-creates Person records for a user.
# Handles Google Contacts CSV exports and Apple Contacts vCard exports.
class CsvImportService
  HEADER_ALIASES = {
    name:            %w[name full_name display_name],
    email:           %w[email e_mail email_address e_mail_address e_mail_1_value],
    notes:           %w[notes note],
    frequency_weeks: %w[frequency_weeks frequency catch_up_frequency],
    timezone:        %w[timezone time_zone tz]
  }.freeze

  Result = Data.define(:created, :skipped, :errors)

  def initialize(file, user)
    @file = file
    @user = user
  end

  def call
    content  = read_content
    filename = @file.respond_to?(:original_filename) ? @file.original_filename.to_s : ""
    rows     = filename.end_with?(".vcf") || vcf_content?(content) ? parse_vcf(content) : parse_csv(content)

    created = 0
    skipped = []
    errors  = []

    rows.each_with_index do |row, i|
      line = i + 2

      name  = row["name"].to_s.strip.presence
      email = row["email"].to_s.strip.presence

      if name.blank? || email.blank?
        errors << "Row #{line}: missing name or email — skipped"
        next
      end

      if @user.people.exists?(email: email.downcase)
        skipped << name
        next
      end

      tz   = valid_timezone(row["timezone"]) || @user.timezone
      freq = row["frequency_weeks"].to_f
      freq = 4.0 if freq <= 0

      person = @user.people.build(
        name: name,
        email: email,
        notes: row["notes"].to_s.strip.presence,
        frequency_weeks: freq,
        timezone: tz
      )

      if person.save
        created += 1
      else
        errors << "Row #{line} (#{name}): #{person.errors.full_messages.join(', ')}"
      end
    rescue StandardError => e
      errors << "Row #{line}: #{e.message}"
    end

    Result.new(created: created, skipped: skipped, errors: errors)
  end

  private

  def read_content
    content = @file.respond_to?(:read) ? @file.read : @file.to_s
    content.delete_prefix("\xEF\xBB\xBF") # strip UTF-8 BOM
  end

  def vcf_content?(content)
    content.lstrip.start_with?("BEGIN:VCARD")
  end

  # ── vCard parsing ──────────────────────────────────────────────────────────

  def parse_vcf(content)
    unfolded = content.gsub(/\r?\n[ \t]/, "") # unfold wrapped lines
    unfolded.scan(/BEGIN:VCARD.*?END:VCARD/mi).filter_map do |card|
      name  = extract_vcf_field(card, "FN")
      # Fall back to N: field (Last;First;Middle;Prefix;Suffix)
      if name.blank?
        n = extract_vcf_field(card, "N")
        parts = n.to_s.split(";").map(&:strip).reject(&:blank?)
        name = parts.rotate(1).join(" ").strip # put first name before last
      end

      email = card.scan(/^EMAIL[^:]*:(.+)$/i).flatten.map(&:strip).reject(&:blank?).first

      next unless name.present? && email.present?

      notes = extract_vcf_field(card, "NOTE")
      { "name" => name, "email" => email, "notes" => notes }
    end
  end

  def extract_vcf_field(card, field)
    val = card.match(/^#{Regexp.escape(field)}[^:]*:(.+)$/i)&.captures&.first&.strip
    return nil if val.nil?

    # Unescape vCard encoding
    val.gsub("\\n", "\n").gsub("\\,", ",").gsub("\\;", ";").gsub("\\\\", "\\")
  end

  # ── CSV parsing ─────────────────────────────────────────────────────────────

  def parse_csv(content)
    csv = CSV.parse(content, headers: true)
    # Normalize headers: lowercase, strip, replace non-alphanumeric with underscore
    normalized = csv.headers.map { |h| h.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "_").delete_suffix("_") }
    rows = csv.map { |row| normalized.zip(row.fields).to_h }
    rows.map { |row| normalize_csv_row(row) }
  end

  # Resolves column aliases and Google Contacts multi-field quirks.
  def normalize_csv_row(row)
    name  = find_alias(row, :name) || google_full_name(row)
    email = find_alias(row, :email) || google_numbered_email(row)
    {
      "name"            => name,
      "email"           => email,
      "notes"           => find_alias(row, :notes),
      "frequency_weeks" => find_alias(row, :frequency_weeks),
      "timezone"        => find_alias(row, :timezone)
    }
  end

  def find_alias(row, field)
    HEADER_ALIASES[field].each do |key|
      val = row[key].to_s.strip
      return val if val.present?
    end
    nil
  end

  def google_full_name(row)
    given  = row["given_name"].to_s.strip
    family = row["family_name"].to_s.strip
    [given, family].reject(&:blank?).join(" ").presence
  end

  def google_numbered_email(row)
    (2..5).each do |n|
      val = row["e_mail_#{n}_value"].to_s.strip
      return val if val.present?
    end
    nil
  end

  def valid_timezone(tz)
    return nil if tz.blank?
    ActiveSupport::TimeZone::MAPPING.values.include?(tz) ? tz : nil
  end
end
