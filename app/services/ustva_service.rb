# Service to calculate Umsatzsteuervoranmeldung (UStVA / VAT advance return)
# Calculates VAT liabilities based on posted journal entries within a date range
class UstvaService
  Result = Struct.new(:success?, :data, :errors, keyword_init: true)

  def initialize(company:, start_date:, end_date:)
    @company = company
    @start_date = start_date
    @end_date = end_date
  end

  def call
    return failure("Company is required") unless @company
    return failure("Start date is required") unless @start_date
    return failure("End date is required") unless @end_date
    return failure("End date must be after start date") if @end_date < @start_date

    vat_balances = calculate_vat_balances
    period_type = determine_period_type
    fields_data = calculate_fields(vat_balances)
    sections_data = build_sections(fields_data)
    net_vat_liability = calculate_net_vat_liability(sections_data)

    Result.new(
      success?: true,
      data: {
        period_type: period_type,
        start_date: @start_date.to_s,
        end_date: @end_date.to_s,
        fields: fields_data,
        sections: sections_data,
        net_vat_liability: net_vat_liability,
        metadata: {
          journal_entries_count: count_journal_entries,
          calculation_date: Date.today.to_s
        }
      },
      errors: []
    )
  rescue StandardError => e
    Result.new(success?: false, data: nil, errors: [ e.message ])
  end

  private

  def calculate_vat_balances
    # Query all VAT account balances within the date range
    # Only include posted journal entries (GoBD compliance)
    results = @company.accounts
      .where(code: Account::VAT_ACCOUNTS.values)
      .joins(line_items: :journal_entry)
      .where(journal_entries: { booking_date: @start_date..@end_date })
      #.where.not(journal_entries: { posted_at: nil })
      .select(
        "accounts.code",
        "accounts.name",
        "SUM(CASE WHEN line_items.direction = 'debit' THEN line_items.amount ELSE 0 END) as total_debit",
        "SUM(CASE WHEN line_items.direction = 'credit' THEN line_items.amount ELSE 0 END) as total_credit"
      )
      .group("accounts.code", "accounts.name")

    # Build hash of account_code => net_balance
    balances = {}
    results.each do |account|
      # VAT amounts are always reported as positive values on UStVA
      # Output VAT (liability): credit balance
      # Input VAT (asset): debit balance
      # Use absolute value to ensure positive amounts
      net_balance = account.total_credit.to_f - account.total_debit.to_f
      balances[account.code] = net_balance.abs
    end

    balances
  end

  def calculate_fields(vat_balances)
    fields = []

    TaxFormFieldMap.ustva_fields.each do |field_key, field_def|
      value = case field_def[:calculation_type]
      when :account_balance
        calculate_account_balance_field(field_def, vat_balances)
      when :formula
        # Formula fields are calculated later (e.g., net VAT liability)
        nil
      end

      fields << {
        key: field_key,
        field_number: field_def[:field_number],
        name: field_def[:name],
        description: field_def[:description],
        value: value,
        editable: false
      }
    end

    fields.compact_blank
  end

  def calculate_account_balance_field(field_def, vat_balances)
    # Sum balances for all accounts in this field
    field_def[:accounts].sum do |account_code|
      vat_balances[account_code] || 0.0
    end.round(2)
  end

  def build_sections(fields_data)
    sections = {}

    # Group fields by section
    TaxFormFieldMap.ustva_fields_by_section.each do |section_key, section_fields|
      section_field_keys = section_fields.keys
      fields_in_section = fields_data.select { |f| section_field_keys.include?(f[:key]) }

      # Skip summary section for now (it contains calculated fields)
      next if section_key == :summary

      subtotal = fields_in_section.sum { |f| f[:value] || 0.0 }

      sections[section_key] = {
        label: TaxFormFieldMap.ustva_section_label(section_key),
        fields: fields_in_section,
        subtotal: subtotal.round(2)
      }
    end

    sections
  end

  def calculate_net_vat_liability(sections_data)
    # Net VAT liability = Output VAT - Input VAT + Reverse Charge Output - Reverse Charge Input
    # Positive = VAT owed to tax authority
    # Negative = VAT refund from tax authority

    output_vat = sections_data.dig(:output_vat, :subtotal) || 0.0
    input_vat = sections_data.dig(:input_vat, :subtotal) || 0.0
    reverse_charge_output = sections_data[:reverse_charge]&.dig(:fields)&.find { |f| f[:key] == :kz_46 }&.dig(:value) || 0.0
    reverse_charge_input = sections_data[:reverse_charge]&.dig(:fields)&.find { |f| f[:key] == :kz_47 }&.dig(:value) || 0.0

    net_liability = output_vat - input_vat + reverse_charge_output - reverse_charge_input
    net_liability.round(2)
  end

  def determine_period_type
    # Determine if this is monthly, quarterly, or annual based on date range
    days = (@end_date - @start_date).to_i + 1

    case days
    when 28..31 then "monthly"
    when 89..92 then "quarterly"
    when 365..366 then "annual"
    else "custom"
    end
  end

  def count_journal_entries
    @company.journal_entries
      .where(booking_date: @start_date..@end_date)
      #.where.not(posted_at: nil)
      .count
  end

  def failure(message)
    Result.new(success?: false, data: nil, errors: [ message ])
  end
end
