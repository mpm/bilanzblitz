require 'rails_helper'

RSpec.describe TaxFormFieldMap do
  describe '.ustva_fields' do
    it 'returns all UStVA field definitions' do
      fields = described_class.ustva_fields

      expect(fields).to be_a(Hash)
      expect(fields).to be_frozen
      expect(fields.keys).to include(:kz_81, :kz_86, :kz_66, :kz_61, :kz_46, :kz_47, :kz_83)
    end

    it 'includes required field attributes' do
      field = described_class.ustva_fields[:kz_81]

      expect(field).to include(:field_number, :name, :description, :calculation_type, :section, :display_order)
      expect(field[:field_number]).to eq(81)
      expect(field[:name]).to eq("Umsatzsteuer 19%")
      expect(field[:section]).to eq(:output_vat)
    end
  end

  describe '.ustva_field' do
    it 'returns the field definition for a valid field key' do
      field = described_class.ustva_field(:kz_81)

      expect(field[:field_number]).to eq(81)
      expect(field[:name]).to eq("Umsatzsteuer 19%")
    end

    it 'raises ArgumentError for an invalid field key' do
      expect {
        described_class.ustva_field(:invalid_key)
      }.to raise_error(ArgumentError, /Unknown UStVA field/)
    end
  end

  describe '.kst_field' do
    it 'returns the field definition for a valid field key' do
      field = described_class.kst_field(:einkommen)

      expect(field[:name]).to eq("Jahresüberschuss/Jahresfehlbetrag")
      expect(field[:section]).to eq(:base_data)
    end

    it 'raises ArgumentError for an invalid field key' do
      expect {
        described_class.kst_field(:invalid_key)
      }.to raise_error(ArgumentError, /Unknown KSt field/)
    end
  end

  describe '.ustva_fields_ordered' do
    it 'returns fields sorted by display_order' do
      fields = described_class.ustva_fields_ordered

      expect(fields).to be_an(Array)
      expect(fields.first[:display_order]).to eq(1)
      expect(fields.last[:display_order]).to eq(7)

      # Verify they're in ascending order
      display_orders = fields.map { |f| f[:display_order] }
      expect(display_orders).to eq(display_orders.sort)
    end
  end

  describe '.ustva_fields_by_section' do
    it 'returns fields grouped by section' do
      sections = described_class.ustva_fields_by_section

      expect(sections).to be_a(Hash)
      expect(sections.keys).to include(:output_vat, :input_vat, :reverse_charge, :summary)
    end

    it 'groups output VAT fields correctly' do
      output_vat = described_class.ustva_fields_by_section[:output_vat]

      expect(output_vat).to be_a(Hash)
      expect(output_vat.keys).to include(:kz_81, :kz_86)
    end

    it 'groups input VAT fields correctly' do
      input_vat = described_class.ustva_fields_by_section[:input_vat]

      expect(input_vat.keys).to include(:kz_66, :kz_61)
    end

    it 'sorts fields within each section by display_order' do
      output_vat = described_class.ustva_fields_by_section[:output_vat]
      display_orders = output_vat.values.map { |f| f[:display_order] }

      expect(display_orders).to eq(display_orders.sort)
    end
  end

  describe '.kst_fields_by_section' do
    it 'returns fields grouped by section' do
      sections = described_class.kst_fields_by_section

      expect(sections).to be_a(Hash)
      expect(sections.keys).to include(:base_data, :adjustments, :calculated)
    end

    it 'groups adjustment fields correctly' do
      adjustments = described_class.kst_fields_by_section[:adjustments]

      expect(adjustments.keys).to include(
        :nicht_abzugsfaehige_aufwendungen,
        :steuerfreie_ertraege,
        :verlustvortrag,
        :spenden,
        :sonderabzuege
      )
    end

    it 'identifies editable fields in adjustments section' do
      adjustments = described_class.kst_fields_by_section[:adjustments]

      adjustments.each do |_key, field|
        expect(field[:editable]).to be true
      end
    end
  end

  describe '.kst_editable_fields' do
    it 'returns only editable fields' do
      editable = described_class.kst_editable_fields

      expect(editable).to be_a(Hash)
      expect(editable.values).to all(include(editable: true))
    end

    it 'includes all adjustment fields' do
      editable = described_class.kst_editable_fields

      expect(editable.keys).to include(
        :nicht_abzugsfaehige_aufwendungen,
        :steuerfreie_ertraege,
        :verlustvortrag,
        :spenden,
        :sonderabzuege
      )
    end

    it 'does not include base data fields' do
      editable = described_class.kst_editable_fields

      expect(editable.keys).not_to include(:einkommen)
    end
  end

  describe '.ustva_section_label' do
    it 'returns the correct label for output_vat' do
      label = described_class.ustva_section_label(:output_vat)
      expect(label).to eq("Umsatzsteuer (Output VAT)")
    end

    it 'returns the correct label for input_vat' do
      label = described_class.ustva_section_label(:input_vat)
      expect(label).to eq("Abziehbare Vorsteuer (Input VAT)")
    end

    it 'raises ArgumentError for unknown section' do
      expect {
        described_class.ustva_section_label(:invalid_section)
      }.to raise_error(ArgumentError, /Unknown UStVA section/)
    end
  end

  describe '.kst_section_label' do
    it 'returns the correct label for base_data' do
      label = described_class.kst_section_label(:base_data)
      expect(label).to eq("Ausgangswerte")
    end

    it 'returns the correct label for adjustments' do
      label = described_class.kst_section_label(:adjustments)
      expect(label).to eq("Außerbilanzielle Korrekturen")
    end

    it 'raises ArgumentError for unknown section' do
      expect {
        described_class.kst_section_label(:invalid_section)
      }.to raise_error(ArgumentError, /Unknown KSt section/)
    end
  end

  describe 'field structure validation' do
    it 'ensures all UStVA fields have required attributes' do
      described_class.ustva_fields.each do |key, field|
        expect(field).to include(:name, :section, :display_order), "Field #{key} missing required attributes"

        case field[:calculation_type]
        when :account_balance
          expect(field).to include(:accounts), "Field #{key} with account_balance type missing :accounts"
        when :formula
          expect(field).to include(:formula), "Field #{key} with formula type missing :formula"
        end
      end
    end

    it 'ensures all KSt fields have required attributes' do
      all_kst_fields = described_class.kst_fields_by_section.values.reduce({}, :merge)

      all_kst_fields.each do |key, field|
        expect(field).to include(:name, :section, :editable, :display_order), "Field #{key} missing required attributes"

        if field[:editable]
          expect(field).to include(:default_value, :adjustment_sign), "Editable field #{key} missing adjustment attributes"
        end
      end
    end
  end

  describe 'VAT account mapping' do
    it 'uses correct VAT account codes from Account::VAT_ACCOUNTS' do
      kz_81 = described_class.ustva_field(:kz_81)
      expect(kz_81[:accounts]).to include(Account::VAT_ACCOUNTS[:output_19])

      kz_66 = described_class.ustva_field(:kz_66)
      expect(kz_66[:accounts]).to include(Account::VAT_ACCOUNTS[:input_19])
    end
  end
end
