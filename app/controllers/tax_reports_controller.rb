# Controller for managing tax reports (UStVA, KSt, etc.)
class TaxReportsController < ApplicationController
  include KeyTransformer
  before_action :authenticate_user!
  before_action :ensure_has_company
  before_action :set_tax_report, only: [ :show, :update, :destroy ]

  # GET /tax_reports
  # List all tax reports with filtering and missing report detection
  def index
    @company = current_user.companies.first
    @tax_reports = @company.tax_reports.order(start_date: :desc)

    # Extract unique calendar years for filtering
    calendar_years = @tax_reports.pluck(:start_date).map(&:year).uniq.sort.reverse

    render inertia: "TaxReports/Index", props: camelize_keys({
      company: serialize_company(@company),
      tax_reports: serialize_tax_reports(@tax_reports),
      calendar_years: calendar_years
    })
  end

  # GET /tax_reports/new
  # Report type and period picker
  def new
    @company = current_user.companies.first
    @fiscal_years = @company.fiscal_years.order(year: :desc)

    render inertia: "TaxReports/New", props: camelize_keys({
      company: serialize_company(@company),
      fiscal_years: serialize_fiscal_years(@fiscal_years),
      report_types: report_types_config
    })
  end

  # POST /tax_reports/generate
  # Generate report preview (not saved to database yet)
  def generate
    @company = current_user.companies.first
    params_data = underscore_keys(params.require(:tax_report).permit!)

    result = generate_report_data(params_data)

    if result.success?
      render inertia: "TaxReports/Show", props: camelize_keys({
        company: serialize_company(@company),
        report_data: result.data.merge(report_type: params_data[:report_type]),
        is_preview: true,
        fiscal_years: serialize_fiscal_years(@company.fiscal_years.order(year: :desc))
      })
    else
      render inertia: "TaxReports/New", props: camelize_keys({
        company: serialize_company(@company),
        fiscal_years: serialize_fiscal_years(@company.fiscal_years.order(year: :desc)),
        report_types: report_types_config,
        errors: result.errors
      })
    end
  end

  # GET /tax_reports/:id
  # View saved tax report
  def show
    render inertia: "TaxReports/Show", props: camelize_keys({
      company: serialize_company(@company),
      tax_report: serialize_tax_report(@tax_report),
      report_data: @tax_report.generated_data,
      is_preview: false,
      fiscal_years: serialize_fiscal_years(@company.fiscal_years.order(year: :desc))
    })
  end

  # POST /tax_reports
  # Save/finalize report to database
  def create
    @company = current_user.companies.first
    params_data = underscore_keys(params.require(:tax_report).permit!)

    # Create tax report record
    @tax_report = @company.tax_reports.new(
      report_type: params_data[:report_type],
      period_type: params_data[:period_type],
      start_date: params_data[:start_date],
      end_date: params_data[:end_date],
      fiscal_year_id: params_data[:fiscal_year_id],
      status: "draft",
      generated_data: params_data[:generated_data]
    )

    if @tax_report.save
      redirect_to tax_report_path(@tax_report)
    else
      render inertia: "TaxReports/Show", props: camelize_keys({
        company: serialize_company(@company),
        report_data: params_data[:generated_data],
        is_preview: true,
        errors: @tax_report.errors.full_messages,
        fiscal_years: serialize_fiscal_years(@company.fiscal_years.order(year: :desc))
      })
    end
  end

  # PATCH /tax_reports/:id
  # Update report (mainly for KSt adjustments)
  def update
    unless @tax_report.editable?
      return render json: { errors: [ "Report is not editable" ] }, status: :unprocessable_entity
    end

    params_data = underscore_keys(params.require(:tax_report).permit!)

    # Recalculate report with new adjustments
    if params_data[:adjustments]
      result = recalculate_report(@tax_report, params_data[:adjustments])

      if result.success?
        @tax_report.update!(generated_data: result.data.merge(report_type: @tax_report.report_type))
        redirect_to tax_report_path(@tax_report)
      else
        render inertia: "TaxReports/Show", props: camelize_keys({
          company: serialize_company(@company),
          tax_report: serialize_tax_report(@tax_report),
          report_data: @tax_report.generated_data,
          is_preview: false,
          errors: result.errors,
          fiscal_years: serialize_fiscal_years(@company.fiscal_years.order(year: :desc))
        })
      end
    else
      # Simple update (status change, etc.)
      if @tax_report.update(tax_report_params)
        redirect_to tax_report_path(@tax_report)
      else
        render json: { errors: @tax_report.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end

  # DELETE /tax_reports/:id
  # Delete a draft tax report
  def destroy
    unless @tax_report.editable?
      return render json: { errors: [ "Cannot delete non-draft reports" ] }, status: :unprocessable_entity
    end

    @tax_report.destroy
    redirect_to tax_reports_path
  end

  # GET /tax_reports/missing_reports
  # API endpoint to detect missing reports for a year
  def missing_reports
    @company = current_user.companies.first
    calendar_year = params[:year].to_i
    report_type = params[:report_type]
    period_type = params[:period_type]

    missing = calculate_missing_periods(calendar_year, report_type, period_type)

    render json: camelize_keys({ missing_periods: missing })
  end

  private

  def set_tax_report
    @company = current_user.companies.first
    @tax_report = @company.tax_reports.find(params[:id])
  end

  def ensure_has_company
    return if current_user.companies.any?

    redirect_to root_path, alert: "You must create a company first"
  end

  def generate_report_data(params_data)
    case params_data[:report_type]
    when "ustva"
      UstvaService.new(
        company: @company,
        start_date: Date.parse(params_data[:start_date]),
        end_date: Date.parse(params_data[:end_date])
      ).call
    when "kst"
      fiscal_year = @company.fiscal_years.find(params_data[:fiscal_year_id])
      KstService.new(
        company: @company,
        fiscal_year: fiscal_year,
        adjustments: params_data[:adjustments] || {}
      ).call
    else
      KstService::Result.new(
        success?: false,
        data: nil,
        errors: [ "Unknown report type: #{params_data[:report_type]}" ]
      )
    end
  end

  def recalculate_report(tax_report, adjustments)
    case tax_report.report_type
    when "kst"
      KstService.new(
        company: @company,
        fiscal_year: tax_report.fiscal_year,
        adjustments: adjustments
      ).call
    else
      # UStVA and other reports are not recalculated (they're based on fixed data)
      KstService::Result.new(
        success?: false,
        data: nil,
        errors: [ "Report type #{tax_report.report_type} does not support recalculation" ]
      )
    end
  end

  def calculate_missing_periods(year, report_type, period_type)
    # Get existing reports for this year/type/period
    existing = @company.tax_reports
      .where(report_type: report_type, period_type: period_type)
      .for_year(year)

    # Generate expected periods
    expected = generate_expected_periods(year, period_type)

    # Filter out existing periods
    existing_keys = existing.map { |r| "#{r.start_date}_#{r.end_date}" }.to_set

    expected.reject { |period| existing_keys.include?("#{period[:start_date]}_#{period[:end_date]}") }
  end

  def generate_expected_periods(year, period_type)
    case period_type
    when "monthly"
      (1..12).map do |month|
        start_date = Date.new(year, month, 1)
        end_date = start_date.end_of_month
        {
          label: start_date.strftime("%B %Y"),
          start_date: start_date.to_s,
          end_date: end_date.to_s
        }
      end
    when "quarterly"
      (1..4).map do |quarter|
        start_month = (quarter - 1) * 3 + 1
        start_date = Date.new(year, start_month, 1)
        end_date = start_date + 2.months
        end_date = end_date.end_of_month
        {
          label: "Q#{quarter} #{year}",
          start_date: start_date.to_s,
          end_date: end_date.to_s
        }
      end
    when "annual"
      [ {
        label: year.to_s,
        start_date: Date.new(year, 1, 1).to_s,
        end_date: Date.new(year, 12, 31).to_s
      } ]
    else
      []
    end
  end

  def report_types_config
    {
      ustva: {
        name: "Umsatzsteuervoranmeldung (UStVA)",
        description: "VAT advance return",
        period_types: [ "monthly", "quarterly", "annual" ]
      },
      kst: {
        name: "Körperschaftsteuer (KSt)",
        description: "Corporate income tax",
        period_types: [ "annual" ]
      }
    }
  end

  def serialize_company(company)
    {
      id: company.id,
      name: company.name
    }
  end

  def serialize_tax_reports(tax_reports)
    tax_reports.map do |report|
      serialize_tax_report(report)
    end
  end

  def serialize_tax_report(report)
    {
      id: report.id,
      report_type: report.report_type,
      report_type_label: report.report_type_label,
      period_type: report.period_type,
      start_date: report.start_date.to_s,
      end_date: report.end_date.to_s,
      status: report.status,
      submitted_at: report.submitted_at&.to_s,
      period_label: report.period_label,
      fiscal_year_id: report.fiscal_year_id,
      editable: report.editable?,
      finalized: report.finalized?
    }
  end

  def serialize_fiscal_years(fiscal_years)
    fiscal_years.map do |fy|
      {
        id: fy.id,
        year: fy.year,
        start_date: fy.start_date.to_s,
        end_date: fy.end_date.to_s,
        closed: fy.closed?
      }
    end
  end

  def tax_report_params
    params.require(:tax_report).permit(:status, :submitted_at)
  end
end
