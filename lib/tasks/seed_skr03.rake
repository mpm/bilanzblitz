namespace :accounting do
  desc "Seed SKR03 chart of accounts from contrib/skr03-accounts.csv"
  task seed_skr03: :environment do
    dry_run = ENV["DRY_RUN"] == "true"

    file_path = Rails.root.join("contrib", "skr03-accounts.csv")

    unless File.exist?(file_path)
      puts "Error: File not found at #{file_path}"
      exit 1
    end

    puts "=" * 80
    puts "SKR03 Chart of Accounts Seeding"
    puts "Mode: #{dry_run ? 'DRY RUN (no records created)' : 'LIVE (creating records)'}"
    puts "=" * 80
    puts

    chart = nil
    templates_data = []
    seen_codes = Hash.new { |h, k| h[k] = [] }

    File.readlines(file_path).each_with_index do |line, index|
      line_number = index + 1

      # Skip comment lines
      next if line.start_with?("#")

      # Strip whitespace
      line = line.strip
      next if line.empty?

      # Split by semicolon: code;flags;range;category;description
      parts = line.split(";", 5)

      # Need exactly 5 parts
      if parts.length != 5
        raise "Non-empty line with more than five columns: #{parts.inspect}"
      end

      code = parts[0].strip
      flags = parts[1].strip
      range = parts[2].strip
      category = parts[3].strip
      description = parts[4].strip

      description = "Unbenannt #{code}" if description.empty?

      # Skip if code is empty
      raise "Code is empty for this line #{parts.inspect}" if code.empty?

      # Track this account code and where it appears
      seen_codes[code] << { line: line_number, description: description }

      # Determine account type based on account number
      account_type = determine_account_type(code)

      # Extract tax rate from description if present
      tax_rate = extract_tax_rate(description)

      # Store flags in config hash
      config = {}
      config["_flags"] = flags unless flags.empty?

      # Check if this is a system account (closing accounts have flag "S")
      is_system_account = flags.include?("S")

      if dry_run
        # In dry mode, just print the parsed data
        puts "#{code.ljust(6)} | #{account_type.ljust(10)} | #{tax_rate.to_s.ljust(5)} | #{range.ljust(12)} | #{category.ljust(8)} | #{description}"
      else
        # Store template data for creation
        templates_data << {
          code: code,
          name: description,
          account_type: account_type,
          tax_rate: tax_rate,
          description: description,
          config: config,
          range: range.presence,
          cid: category == "NONE" ? nil : category,
          is_system_account: is_system_account
        }
      end
    end

    # Check for duplicates
    duplicates = seen_codes.select { |code, occurrences| occurrences.length > 1 }

    if duplicates.any?
      puts
      puts "!" * 80
      puts "WARNING: DUPLICATE ACCOUNT CODES FOUND!"
      puts "!" * 80
      puts

      duplicates.each do |code, occurrences|
        puts "Account code: #{code} (appears #{occurrences.length} times)"
        occurrences.each do |occurrence|
          puts "  Line #{occurrence[:line]}: #{occurrence[:description]}"
        end
        puts
      end

      puts "Total unique codes with duplicates: #{duplicates.length}"
      puts "!" * 80
    end

    puts
    puts "=" * 80
    puts "Parsing complete!"
    puts "Total accounts parsed: #{seen_codes.keys.length}"
    puts "Total entries (including duplicates): #{templates_data.length}" unless dry_run
    puts "=" * 80

    unless dry_run
      # Prevent seeding if duplicates exist
      if duplicates.any?
        puts
        puts "ERROR: Cannot proceed with seeding due to duplicate account codes."
        puts "Please fix the duplicates in the source file and try again."
        exit 1
      end

      puts
      puts "Creating ChartOfAccounts and AccountTemplates..."

      ActiveRecord::Base.transaction do
        # Create or find the SKR03 chart
        chart = ChartOfAccounts.find_or_create_by!(name: "SKR03") do |c|
          c.country_code = "DE"
          c.description = "DATEV-Kontenrahmen SKR03 (Prozessgliederungsprinzip)"
        end

        puts "ChartOfAccounts created/found: #{chart.name} (ID: #{chart.id})"

        # Delete existing templates for this chart to avoid duplicates
        deleted_count = chart.account_templates.delete_all
        puts "Deleted #{deleted_count} existing account templates"

        # Deduplicate templates_data by code (keep first occurrence)
        unique_templates = templates_data.uniq { |t| t[:code] }
        puts "Creating #{unique_templates.length} unique account templates..."

        # Create all account templates
        created_count = 0
        unique_templates.each do |template_data|
          chart.account_templates.create!(template_data)
          created_count += 1

          # Print progress every 100 accounts
          if created_count % 100 == 0
            print "."
            STDOUT.flush
          end
        end

        puts
        puts "Created #{created_count} account templates"
      end

      puts
      puts "✓ SKR03 seeding completed successfully!"
    end
  end

  private

  # Determine account type based on SKR03 (Prozessgliederungsprinzip) structure
  # Klasse 0: Anlage- und Kapitalkonten (fixed assets and capital/equity)
  # Klasse 1: Finanz- und Privatkonten (cash, bank, receivables, payables)
  # Klasse 2: Abgrenzungskonten (deferrals - can be assets or liabilities)
  # Klasse 3: Wareneingangs- und Bestandskonten (inventory - assets)
  # Klasse 4, 5, 6: Betriebliche Aufwendungen (operating expenses)
  # Klasse 8: Erlöskonten (revenue)
  # Klasse 9: Vortrags- und statistische Konten (carryforward/closing - equity)
  def determine_account_type(account_code)
    account_num = account_code.to_i

    case account_num
    # Class 0: Fixed assets and capital accounts
    when 0...800
      "asset" # Fixed assets (intangible, tangible, financial assets)
    when 800...1000
      "equity" # Capital accounts, equity

    # Class 1: Finance and private accounts
    when 1000...1600
      "asset" # Cash, bank, receivables
    when 1600...1800
      "liability" # Payables (Verbindlichkeiten)
    when 1800...2000
      "asset" # Other current assets

    # Class 2: Deferral accounts
    when 2000...2200
      "equity" # Equity accounts
    when 2200...2400
      "liability" # Provisions (Rückstellungen)
    when 2400...3000
      "liability" # Liabilities and deferrals

    # Class 3: Inventory accounts
    when 3000...4000
      "asset" # Raw materials, goods, work in progress

    # Class 4, 5, 6: Expense accounts
    when 4000...7000
      "expense" # Operating expenses

    # Class 7: Additional expenses or cost types
    when 7000...8000
      "expense" # Other expenses

    # Class 8: Revenue accounts
    when 8000...9000
      "revenue" # Sales revenue and closing accounts

    # Class 9: Carryforward and statistical accounts
    when 9000...10000
      "equity" # Cost accounting, closing, carryforward

    else
      "asset" # Default fallback
    end
  end

  # Extract tax rate from description if present (e.g., "7 %", "19 %")
  def extract_tax_rate(description)
    return 0.0 if description.nil?

    # Look for patterns like "7 %", "19 %", "16 %", etc.
    if description =~ /(\d+(?:,\d+)?)\s*%/
      rate = $1.gsub(",", ".").to_f
      return rate
    end

    0.0
  end
end
