class TransactionCsvParser
  ParseResult = Struct.new(:booking_date, :value_date, :amount, :remittance_information, :counterparty_name, :counterparty_iban, keyword_init: true)

  def initialize(csv_data)
    @csv_data = csv_data
  end

  def parse
    return [] if @csv_data.blank?

    lines = @csv_data.strip.split("\n")
    return [] if lines.empty?

    delimiter = detect_delimiter(lines.first)
    headers = lines.first.split(delimiter).map(&:strip).map(&:downcase)
    has_header = header_row?(headers)

    data_lines = has_header ? lines[1..] : lines

    data_lines.filter_map do |line|
      columns = line.split(delimiter).map(&:strip)
      next if columns.empty? || columns.all?(&:blank?)

      parse_transaction_row(columns, has_header ? headers : nil)
    end
  end

  def self.parse_german_date(str)
    new(nil).parse_german_date(str)
  end

  def self.parse_german_amount(str)
    new(nil).parse_german_amount(str)
  end

  def parse_german_date(str)
    return nil if str.blank?

    str = str.strip

    # Try German format first: DD.MM.YYYY or DD.MM.YY
    if str.match?(/^\d{1,2}\.\d{1,2}\.\d{2,4}$/)
      parts = str.split(".")
      day = parts[0].to_i
      month = parts[1].to_i
      year = parts[2].to_i
      year += 2000 if year < 100
      return Date.new(year, month, day)
    end

    # Try ISO format: YYYY-MM-DD
    if str.match?(/^\d{4}-\d{2}-\d{2}$/)
      return Date.parse(str)
    end

    nil
  rescue ArgumentError
    nil
  end

  def parse_german_amount(str)
    return nil if str.blank?

    str = str.strip
    # Remove currency symbols and whitespace
    str = str.gsub(/[€EUR\s]/, "")

    # Handle German number format: 1.234,56 -> 1234.56
    if str.include?(",")
      # German format: periods are thousands separators, comma is decimal
      str = str.gsub(".", "").gsub(",", ".")
    end

    str.to_f
  rescue ArgumentError
    nil
  end

  private

  def detect_delimiter(first_line)
    if first_line.include?("\t")
      "\t"
    elsif first_line.include?(";")
      ";"
    else
      ","
    end
  end

  def header_row?(headers)
    headers.any? { |h| h.match?(/datum|date|betrag|amount|verwendungszweck/) }
  end

  def parse_transaction_row(columns, headers)
    if headers
      parse_with_headers(columns, headers)
    else
      parse_without_headers(columns)
    end
  end

  def parse_with_headers(columns, headers)
    data = headers.zip(columns).to_h

    booking_date = find_date_value(data, %w[buchungstag buchungsdatum booking_date date datum])
    value_date = find_date_value(data, %w[valuta wertstellung value_date valutadatum])
    amount = find_amount_value(data, %w[betrag amount umsatz soll/haben])
    remittance = find_text_value(data, %w[verwendungszweck remittance description beschreibung text])
    counterparty = find_text_value(data, %w[auftraggeber/empfänger name gegenkonto beguenstigter zahlungspflichtiger counterparty])
    counterparty_iban = find_text_value(data, %w[iban kontonummer account])

    ParseResult.new(
      booking_date: booking_date || Date.today,
      value_date: value_date,
      amount: amount || 0,
      remittance_information: remittance,
      counterparty_name: counterparty,
      counterparty_iban: counterparty_iban
    )
  end

  def parse_without_headers(columns)
    booking_date = nil
    value_date = nil
    amount = nil
    texts = []

    columns.each do |col|
      if booking_date.nil? && looks_like_date?(col)
        booking_date = parse_german_date(col)
      elsif booking_date && value_date.nil? && looks_like_date?(col)
        value_date = parse_german_date(col)
      elsif amount.nil? && looks_like_amount?(col)
        amount = parse_german_amount(col)
      else
        texts << col unless col.blank?
      end
    end

    ParseResult.new(
      booking_date: booking_date || Date.today,
      value_date: value_date,
      amount: amount || 0,
      remittance_information: texts.first,
      counterparty_name: texts.second,
      counterparty_iban: nil
    )
  end

  def find_date_value(data, keys)
    keys.each do |key|
      value = data[key]
      return parse_german_date(value) if value.present?
    end
    nil
  end

  def find_amount_value(data, keys)
    keys.each do |key|
      value = data[key]
      return parse_german_amount(value) if value.present?
    end
    nil
  end

  def find_text_value(data, keys)
    keys.each do |key|
      value = data[key]
      return value if value.present?
    end
    nil
  end

  def looks_like_date?(str)
    # German date format: DD.MM.YYYY or DD.MM.YY
    str.match?(/^\d{1,2}\.\d{1,2}\.\d{2,4}$/) ||
    # ISO format: YYYY-MM-DD
    str.match?(/^\d{4}-\d{2}-\d{2}$/)
  end

  def looks_like_amount?(str)
    # German amount format: 1.234,56 or -1.234,56 € or 1234.56
    str.match?(/^-?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})?(?:\s*(?:€|EUR))?$/) ||
    str.match?(/^-?\d+[.,]\d{2}(?:\s*(?:€|EUR))?$/)
  end
end
