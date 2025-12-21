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

      # Split by semicolon: code;flags;range;cid;presentation_rule;description
      parts = line.split(";", 6)

      # Need exactly 6 parts
      if parts.length != 6
        raise "Non-empty line with wrong number of columns (expected 6, got #{parts.length}): #{parts.inspect}"
      end

      code = parts[0].strip
      flags = parts[1].strip
      range = parts[2].strip
      cid = parts[3].strip
      presentation_rule = parts[4].strip
      description = parts[5].strip

      description = "Unbenannt #{code}" if description.empty?

      # Skip if code is empty
      raise "Code is empty for this line #{parts.inspect}" if code.empty?

      # Track this account code and where it appears
      seen_codes[code] << { line: line_number, description: description }

      # Determine account type based on account number and cid
      account_type = determine_account_type(code, cid)

      # Extract tax rate from description if present
      tax_rate = extract_tax_rate(description)

      # Store flags and presentation rule in config hash
      config = {}
      config["_flags"] = flags unless flags.empty?
      config["_presentation_rule"] = presentation_rule unless presentation_rule.empty?

      # Check if this is a system account (closing accounts have flag "S")
      is_system_account = flags.include?("S")

      if dry_run
        # In dry mode, just print the parsed data
        puts "#{code.ljust(6)} | #{account_type.ljust(10)} | #{tax_rate.to_s.ljust(5)} | #{range.ljust(12)} | #{cid.ljust(8)} | #{presentation_rule.ljust(12)} | #{description}"
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
          cid: cid.empty? ? nil : cid,
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

        # Now update existing accounts with new account_type from templates
        puts
        puts "Updating existing accounts with account_type from templates..."

        existing_updates = 0
        Account.find_each do |account|
          template = chart.account_templates.find_by(code: account.code)
          next unless template

          if account.account_type != template.account_type
            account.update!(account_type: template.account_type)
            existing_updates += 1
            print "+"
            STDOUT.flush
          end
        end

        puts
        puts "Updated #{existing_updates} existing accounts with new account_type"
      end

      puts
      puts "✓ SKR03 seeding completed successfully!"
    end
  end

  private

  # Determine account type using AccountMap category-based lookup
  # @param account_code [String] The account code (e.g., "0750")
  # @param cid [String] The category identifier from CSV (can be empty)
  # @return [String] The account type ("asset", "liability", "equity", "expense", "revenue")
  def determine_account_type(account_code, cid)
    account_num = account_code.to_i

    # Special handling: 9xxx accounts (closing/carryforward) - always equity
    return "equity" if account_num >= 9000 && account_num < 10000

    # If cid is empty, use fallback logic
    if cid.nil? || cid.empty?
      return fallback_account_type(account_num)
    end

    # Primary method: Look up account code in AccountMap
    account_type = AccountMap.account_type_for_code(account_code)

    # If found, return it
    return account_type if account_type

    # Fallback if not found in any category
    puts "ℹ️  INFO: Account #{account_code} not found in AccountMap categories, using fallback"
    fallback_account_type(account_num)
  end

  # Fallback account type determination for uncategorized accounts
  # @param account_num [Integer] The numeric account code
  # @return [String] The account type
  def fallback_account_type(account_num)
    case account_num
    when 0...4000
      "asset"  # Conservative default for 0-3999
    when 4000...8000
      "expense"
    when 8000...9000
      "revenue"
    else
      "equity"  # 9xxx accounts
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
