# Service to map accounts to GuV sections and balance sheet categories
# Provides centralized configuration for account categorization according to § 275 Abs. 2 HGB
class AccountMap
  # Define GuV sections according to § 275 Abs. 2 HGB (Gesamtkostenverfahren)
  GUV_SECTIONS = {
    umsatzerloese: {
      title: "1. Umsatzerlöse",
      accounts: [ "2750-2753", "2764", "8000", "8100", "8105", "8110", "8120", "8125", "8128", "8135", "8140", "8150", "8160", "8165", "8190-8197", "8200", "8290", "8300", "8310", "8315", "8320", "8330-8340", "8400", "8410", "8420", "8449", "8499", "8510-8511", "8514-8516", "8519-8520", "8540", "8570-8571", "8574-8577", "8579-8582", "8589", "8607", "8700-8706", "8710-8712", "8719-8722", "8724-8728", "8730-8732", "8734-8738", "8741-8750", "8752", "8760", "8762", "8769-8770", "8780", "8782", "8790", "8792", "8950", "8955", "8959" ]
    },
    bestandsveraenderungen: {
      title: "2. Erhöhung oder Verminderung des Bestands an fertigen und unfertigen Erzeugnissen",
      accounts: []
    },
    aktivierte_eigenleistungen: {
      title: "3. Andere aktivierte Eigenleistungen",
      accounts: [ "8990", "8994-8995" ]
    },
    sonstige_betriebliche_ertraege: {
      title: "4. Sonstige betriebliche Erträge",
      accounts: [ "2315-2318", "2504", "2510", "2520", "2590", "2594", "2660-2661", "2666", "2700", "2705", "2707", "2709-2716", "2724-2732", "2735-2737", "2740-2744", "2746-2747", "2749", "2760", "2762", "8590-8591", "8595-8596", "8603-8606", "8609-8614", "8625", "8630", "8635", "8640", "8645", "8649", "8820", "8826", "8828-8829", "8837-8839", "8850-8853", "8900", "8905-8906", "8908", "8910", "8913", "8915", "8917-8925", "8928-8935", "8938-8940", "8944-8945", "8947-8949" ]
    },
    materialaufwand_roh_hilfs_betriebsstoffe: {
      title: "5a. Aufwendungen für Roh-, Hilfs- und Betriebsstoffe und für bezogene Waren",
      accounts: [ "3000", "3010", "3020", "3029-3030", "3040", "3060-3062", "3064", "3066-3068", "3070-3072", "3075-3077", "3089-3093", "3300", "3310", "3347-3349", "3400", "3410", "3418-3420", "3425", "3430-3431", "3435-3436", "3440-3441", "3500", "3505", "3510", "3540", "3550-3554", "3558-3561", "3565-3566", "3600", "3610", "3620", "3650", "3660", "3700-3701", "3710", "3712", "3714-3718", "3720", "3722", "3724-3726", "3730-3750", "3752-3756", "3760", "3762", "3769-3770", "3780", "3782-3788", "3790", "3792-3796", "3798-3800", "3830", "3850", "3950", "3955", "3960", "3990", "4000" ]
    },
    materialaufwand_bezogene_leistungen: {
      title: "5b. Aufwendungen für bezogene Leistungen",
      accounts: [ "3106-3111", "3113-3116", "3120", "3122-3125", "3127", "3130-3131", "3133-3136", "3140", "3142-3145", "3147", "3150-3155", "3160", "3165", "3170", "3175", "3180", "3185" ]
    },
    personalaufwand_loehne_gehaelter: {
      title: "6a. Löhne und Gehälter",
      accounts: [ "4100", "4110", "4120", "4124-4129", "4145-4159", "4170", "4175", "4180", "4190", "4194-4199" ]
    },
    personalaufwand_soziale_abgaben: {
      title: "6b. Soziale Abgaben und Aufwendungen für Altersversorgung und für Unterstützung",
      accounts: [ "4130", "4137-4138", "4140-4141", "4144", "4160", "4165-4169" ]
    },
    abschreibungen_anlagevermoegen: {
      title: "7a. Abschreibungen auf immaterielle Vermögensgegenstände des Anlagevermögens und Sachanlagen",
      accounts: [ "2430-2431", "2436", "2440-2441", "4880", "4882", "4892-4893" ]
    },
    abschreibungen_umlaufvermoegen: {
      title: "7b. Abschreibungen auf Vermögensgegenstände des Umlaufvermögens",
      accounts: []
    },
    sonstige_betriebliche_aufwendungen: {
      title: "8. Sonstige betriebliche Aufwendungen",
      accounts: [ "2004", "2007", "2010", "2020", "2090-2091", "2094", "2150-2151", "2166", "2170-2171", "2176", "2300", "2307-2313", "2324-2328", "2339", "2342-2345", "2347", "2350", "2380-2387", "2389-2390", "2400-2403", "2406", "2408", "2450-2451", "2890-2895", "4139", "4200", "4210-4212", "4215", "4219-4220", "4222", "4228-4230", "4240", "4250", "4260", "4270", "4280", "4287-4290", "4300-4301", "4304", "4360", "4366", "4370", "4380", "4390", "4396-4397", "4400", "4500", "4520", "4530", "4540", "4550", "4560", "4570", "4575", "4580", "4590", "4595", "4600", "4605", "4630-4632", "4635-4640", "4650-4655", "4660", "4663-4664", "4666", "4668", "4670", "4672-4674", "4676", "4678-4681", "4700", "4710", "4730", "4750", "4760", "4790", "4800-4801", "4805-4806", "4808-4810", "4886-4887", "4900", "4902", "4905", "4909-4910", "4920", "4925", "4930", "4940", "4945-4946", "4948-4950", "4955", "4957-4961", "4963-4965", "4969-4971", "4975-4977", "4980", "4985", "4990-5000", "5999-6000", "6999", "8800-8801", "8807-8809", "8818-8819" ]
    },
    ertraege_beteiligungen: {
      title: "9. Erträge aus Beteiligungen",
      accounts: [ "2600", "2603", "2613-2616", "2618-2619" ]
    },
    ertraege_wertpapiere: {
      title: "10. Erträge aus anderen Wertpapieren und Ausleihungen des Finanzanlagevermögens",
      accounts: [ "2620-2623", "2625-2626", "2640-2641", "2646-2649" ]
    },
    sonstige_zinsen_ertraege: {
      title: "11. Sonstige Zinsen und ähnliche Erträge",
      accounts: [ "2650", "2654-2659", "2680", "2682-2685", "2689", "8650", "8660" ]
    },
    abschreibungen_finanzanlagen: {
      title: "12. Abschreibungen auf Finanzanlagen und auf Wertpapiere des Umlaufvermögens",
      accounts: [ "4866", "4870-4878" ]
    },
    zinsen_aufwendungen: {
      title: "13. Zinsen und ähnliche Aufwendungen",
      accounts: [ "2100", "2102-2105", "2107-2111", "2113-2120", "2123-2129", "2140-2145", "2148-2149" ]
    },
    steuern_einkommen_ertrag: {
      title: "14. Steuern vom Einkommen und vom Ertrag",
      accounts: []
    },
    sonstige_steuern: {
      title: "16. Sonstige Steuern",
      accounts: [ "2285", "2287", "2289", "2375", "4340", "4350", "4355", "4510" ]
    }
  }.freeze

  # Balance sheet categories
  BALANCE_SHEET_CATEGORIES = {
    anlagevermoegen: {
      title: "Anlagevermögen",
      accounts: [ "0010", "0015", "0020", "0025", "0027", "0030", "0035", "0038-0039", "0043-0048", "0050", "0059-0060", "0065", "0070", "0075", "0079-0080", "0085", "0090", "0100", "0110-0113", "0115", "0120", "0129", "0140", "0145-0150", "0159-0160", "0165", "0170", "0175-0180", "0189-0195", "0199", "0210", "0220", "0240", "0260", "0280", "0290", "0299-0300", "0310", "0320", "0350", "0380", "0400", "0410", "0420", "0430", "0440", "0450", "0460", "0480", "0485", "0490", "0498-0510", "0513", "0516-0520", "0523-0525", "0530", "0535", "0538", "0540", "0550", "0580", "0582", "0584", "0586", "0590", "1340", "1344", "1510-1513", "1517-1518" ]
    },
    umlaufvermoegen: {
      title: "Umlaufvermögen",
      accounts: [ "0038-0039", "0500-0504", "0509", "1000", "1010", "1020", "1310", "1329-1330", "1340", "1344", "1348-1350", "1352-1353", "1355-1356", "1373", "1376-1379", "1381-1383", "1385-1387", "1470-1471", "1475", "1480-1481", "1485", "1500-1508", "1510-1513", "1517-1522", "1524-1531", "1537", "1539-1540", "1542-1551", "1555", "1594-1599", "3970", "3980", "7000", "7050", "7080", "7100", "7110", "7140", "9960", "9962", "9965" ]
    },
    eigenkapital: {
      title: "Eigenkapital",
      accounts: [ "0800", "0809", "0840-0846", "0848-0849", "0851", "0853-0859", "0987-0988" ]
    },
    fremdkapital: {
      title: "Fremdkapital",
      accounts: [ "0600-0601", "0605", "0610", "0615-0616", "0620", "0625", "0630", "0640", "0650", "0660", "0670", "0680", "0690", "0699-0701", "0705", "0710", "0715-0716", "0720", "0725", "0730", "0740", "0750", "0755", "0760", "0764", "0767", "0770", "0774", "0777", "0780", "0784", "0787", "0790", "0799", "0950-0956", "0961-0966", "0969-0971", "0973-0974", "0976-0979", "1630-1631", "1635", "1638", "1640-1641", "1645", "1648", "1665-1668", "1670-1673", "1675-1678", "1691", "1695-1698", "1700-1712", "1714-1715", "1717-1721", "1728-1740", "1746-1754", "1767-1768", "1795-1798", "9961", "9963-9964" ]
    }
  }.freeze

# Nested balance sheet categories with hierarchical structure
# Generated from bilanz-with-categories.json
NESTED_BALANCE_SHEET_CATEGORIES = {
  aktiva: {
    anlagevermoegen: {
      name: "Anlagevermögen",
      codes: [],
      children: {
        immaterielle_vermogensgegenstaende: {
          name: "Immaterielle Vermögensgegenstände",
          codes: [],
          children: {
            selbst_geschaffene_schutzrechte: {
              name: "Selbst geschaffene gewerbliche Schutzrechte und ähnliche Rechte und Werte",
              codes: [ "0043-0048" ],
              children: {}
            },
            erworbene_konzessionen: {
              name: "entgeltlich erworbene Konzessionen, gewerbliche Schutzrechte und ähnliche Rechte und Werte sowie Lizenzen an solchen Rechten und Werten",
              codes: [ "0010", "0015", "0020", "0025", "0027", "0030" ],
              children: {}
            },
            geschaefts_firmenwert: {
              name: "Geschäfts- oder Firmenwert",
              codes: [ "0035" ],
              children: {}
            },
            geleistete_anzahlungen_immaterielle: {
              name: "geleistete Anzahlungen",
              codes: [ "0038-0039", "1510-1513", "1517-1518" ],
              children: {}
            }
          }
        },
        sachanlagen: {
          name: "Sachanlagen",
          codes: [],
          children: {
            grundstuecke_bauten: {
              name: "Grundstücke, grundstücksgleiche Rechte und Bauten einschließlich der Bauten auf fremden Grundstücken",
              codes: [ "0050", "0059-0060", "0065", "0070", "0075", "0080", "0085", "0090", "0100", "0110-0113", "0115", "0140", "0145-0149", "0160", "0165", "0170", "0175-0179", "0190-0194" ],
              children: {}
            },
            technische_anlagen_maschinen: {
              name: "technische Anlagen und Maschinen",
              codes: [ "0210", "0220", "0240", "0260", "0280" ],
              children: {}
            },
            betriebs_geschaeftsausstattung: {
              name: "andere Anlagen, Betriebs- und Geschäftsausstattung",
              codes: [ "0300", "0310", "0320", "0350", "0380", "0400", "0410", "0420", "0430", "0440", "0450", "0460", "0480", "0485", "0490" ],
              children: {}
            },
            geleistete_anzahlungen_anlagen_im_bau: {
              name: "geleistete Anzahlungen und Anlagen im Bau",
              codes: [ "0079", "0120", "0129", "0150", "0159", "0180", "0189", "0195", "0199", "0290", "0299", "0498-0499" ],
              children: {}
            }
          }
        },
        finanzanlagen: {
          name: "Finanzanlagen",
          codes: [],
          children: {
            anteile_verbundene_unternehmen_finanzanlagen: {
              name: "Anteile an verbundenen Unternehmen",
              codes: [ "0500-0504", "0509", "1340", "1344" ],
              children: {}
            },
            ausleihungen_verbundene_unternehmen: {
              name: "Ausleihungen an verbundene Unternehmen",
              codes: [ "0505-0508" ],
              children: {}
            },
            beteiligungen: {
              name: "Beteiligungen",
              codes: [ "0510", "0513", "0516-0519" ],
              children: {}
            },
            ausleihungen_beteiligungsverhaeltnis: {
              name: "Ausleihungen an Unternehmen, mit denen ein Beteiligungsverhältnis besteht",
              codes: [ "0520", "0523-0524" ],
              children: {}
            },
            wertpapiere_anlagevermoegen: {
              name: "Wertpapiere des Anlagevermögens",
              codes: [ "0525", "0530", "0535", "0538" ],
              children: {}
            },
            sonstige_ausleihungen: {
              name: "sonstige Ausleihungen.",
              codes: [ "0540", "0550", "0580", "0582", "0584", "0586", "0590" ],
              children: {}
            }
          }
        }
      }
    },
    umlaufvermoegen: {
      name: "Umlaufvermögen",
      codes: [],
      children: {
        vorraete: {
          name: "Vorräte",
          codes: [],
          children: {
            roh_hilfs_betriebsstoffe: {
              name: "Roh-, Hilfs- und Betriebsstoffe",
              codes: [ "3970" ],
              children: {}
            },
            unfertige_erzeugnisse: {
              name: "unfertige Erzeugnisse, unfertige Leistungen",
              codes: [ "7000", "7050", "7080" ],
              children: {}
            },
            fertige_erzeugnisse_waren: {
              name: "fertige Erzeugnisse und Waren",
              codes: [ "3980", "7100", "7110", "7140" ],
              children: {}
            },
            geleistete_anzahlungen_vorraete: {
              name: "geleistete Anzahlungen",
              codes: [ "0038-0039", "1510-1513", "1517-1518" ],
              children: {}
            }
          }
        },
        forderungen_sonstige_vermogensgegenstaende: {
          name: "Forderungen und sonstige Vermögensgegenstände",
          codes: [],
          children: {
            forderungen_lieferungen_leistungen: {
              name: "Forderungen aus Lieferungen und Leistungen",
              codes: [ "9960" ],
              children: {}
            },
            forderungen_verbundene_unternehmen: {
              name: "Forderungen gegen verbundene Unternehmen",
              codes: [ "1310", "1470-1471", "1475", "1594-1596" ],
              children: {}
            },
            forderungen_beteiligungsverhaeltnis: {
              name: "Forderungen gegen Unternehmen, mit denen ein Beteiligungsverhältnis besteht",
              codes: [ "1480-1481", "1485", "1597-1599" ],
              children: {}
            },
            sonstige_vermogensgegenstaende: {
              name: "sonstige Vermögensgegenstände",
              codes: [ "1350", "1352-1353", "1355-1356", "1373", "1376-1379", "1381-1383", "1385-1387", "1500-1508", "1519-1522", "1524-1531", "1537", "1539-1540", "1542-1551", "1555", "9965" ],
              children: {}
            }
          }
        },
        wertpapiere_umlaufvermoegen: {
          name: "Wertpapiere",
          codes: [],
          children: {
            anteile_verbundene_unternehmen_wertpapiere: {
              name: "Anteile an verbundenen Unternehmen",
              codes: [ "0500-0504", "0509", "1340", "1344" ],
              children: {}
            },
            sonstige_wertpapiere: {
              name: "sonstige Wertpapiere",
              codes: [ "1329", "1348-1349" ],
              children: {}
            }
          }
        },
        liquide_mittel: {
          name: "Kassenbestand, Bundesbankguthaben, Guthaben bei Kreditinstituten und Schecks",
          codes: [ "1000", "1010", "1020", "1330", "9962" ],
          children: {}
        }
      }
    }
  },
  passiva: {
    eigenkapital: {
      name: "Eigenkapital",
      codes: [],
      children: {
        gezeichnetes_kapital: {
          name: "Gezeichnetes Kapital",
          codes: [ "0800", "0809" ],
          children: {}
        },
        kapitalruecklage: {
          name: "Kapitalrücklage",
          codes: [ "0840-0845" ],
          children: {}
        },
        gewinnruecklagen: {
          name: "Gewinnrücklagen",
          codes: [],
          children: {
            gesetzliche_ruecklage: {
              name: "gesetzliche Rücklage",
              codes: [ "0846" ],
              children: {}
            },
            ruecklage_anteile: {
              name: "Rücklage für Anteile an einem herrschenden oder mehrheitlich beteiligten Unternehmen",
              codes: [ "0849" ],
              children: {}
            },
            satzungsmaessige_ruecklagen: {
              name: "satzungsmäßige Rücklagen",
              codes: [ "0851" ],
              children: {}
            },
            andere_gewinnruecklagen: {
              name: "andere Gewinnrücklagen",
              codes: [ "0848", "0853-0859", "0987-0988" ],
              children: {}
            }
          }
        },
        gewinnvortrag_verlustvortrag: {
          name: "Gewinnvortrag/Verlustvortrag",
          codes: [],
          children: {}
        }
      }
    },
    rueckstellungen: {
      name: "Rückstellungen",
      codes: [ "0951" ],
      children: {}
    },
    verbindlichkeiten: {
      name: "Verbindlichkeiten",
      codes: [ "0630", "0640", "0650", "0660", "0670", "0680", "0690" ],
      children: {}
    }
  }
}.freeze


  class << self
    # Get the human-readable title for a GuV section
    # @param section_id [Symbol] The section identifier (e.g., :umsatzerloese)
    # @return [String] The section title
    # @raise [ArgumentError] if section_id is unknown
    def section_title(section_id)
      validate_guv_section!(section_id)
      GUV_SECTIONS[section_id][:title]
    end

    # Get the full list of account codes for a GuV section (expands ranges)
    # @param section_id [Symbol] The section identifier
    # @return [Array<String>] Array of account codes
    # @raise [ArgumentError] if section_id is unknown
    def account_codes(section_id)
      validate_guv_section!(section_id)
      expand_account_ranges(GUV_SECTIONS[section_id][:accounts])
    end

    # Filter accounts list to only include those matching the given section
    # @param account_list [Array<Hash>] List of account hashes with :code key
    # @param section_id [Symbol] The section identifier
    # @return [Array<Hash>] Filtered list of accounts
    # @raise [ArgumentError] if section_id is unknown
    def find_accounts(account_list, section_id)
      validate_guv_section!(section_id)
      section_codes = account_codes(section_id)

      # If section has no configured accounts, return empty array
      return [] if section_codes.empty?

      # Filter accounts whose code matches the section
      account_list.select do |account|
        section_codes.include?(account[:code])
      end
    end

    # Get balance sheet category title (stub for future implementation)
    # @param category_id [Symbol] The category identifier
    # @return [String] The category title
    # @raise [ArgumentError] if category_id is unknown
    def balance_sheet_category_title(category_id)
      validate_balance_sheet_category!(category_id)
      BALANCE_SHEET_CATEGORIES[category_id][:title]
    end

    # Get account codes for balance sheet category (stub for future implementation)
    # @param category_id [Symbol] The category identifier
    # @return [Array<String>] Array of account codes
    # @raise [ArgumentError] if category_id is unknown
    def balance_sheet_account_codes(category_id)
      validate_balance_sheet_category!(category_id)
      expand_account_ranges(BALANCE_SHEET_CATEGORIES[category_id][:accounts])
    end

    # Filter accounts by balance sheet category (stub for future implementation)
    # @param account_list [Array<Hash>] List of account hashes with :code key
    # @param category_id [Symbol] The category identifier
    # @return [Array<Hash>] Filtered list of accounts
    # @raise [ArgumentError] if category_id is unknown
    def find_balance_sheet_accounts(account_list, category_id)
      validate_balance_sheet_category!(category_id)
      category_codes = balance_sheet_account_codes(category_id)

      return [] if category_codes.empty?

      account_list.select do |account|
        category_codes.include?(account[:code])
      end
    end

    # Get nested category structure for a top-level category
    # @param category_id [Symbol] The top-level category (:anlagevermoegen, :umlaufvermoegen, etc.)
    # @return [Hash] Nested structure with name, codes, children
    # @raise [ArgumentError] if category_id is not a valid top-level category
    def nested_category_structure(category_id)
      validate_nested_category!(category_id)

      # Search in aktiva
      if NESTED_BALANCE_SHEET_CATEGORIES[:aktiva].key?(category_id)
        return NESTED_BALANCE_SHEET_CATEGORIES[:aktiva][category_id]
      end

      # Search in passiva
      if NESTED_BALANCE_SHEET_CATEGORIES[:passiva].key?(category_id)
        return NESTED_BALANCE_SHEET_CATEGORIES[:passiva][category_id]
      end

      raise ArgumentError, "Category #{category_id} not found in nested structure"
    end

    # Get the official German name for any category (works with nested categories)
    # @param category_id [Symbol] Any category identifier
    # @return [String, nil] The German name or nil if not found
    def category_name(category_id)
      # Check top-level flat categories first (backward compatibility)
      if BALANCE_SHEET_CATEGORIES.key?(category_id)
        return BALANCE_SHEET_CATEGORIES[category_id][:title]
      end

      # Search nested structure
      found = find_in_nested_structure(category_id)
      found ? found[:name] : nil
    end

    # Get all account codes for a category (works with nested categories, flattens all children)
    # @param category_id [Symbol] Any category identifier
    # @return [Array<String>] Array of account codes
    def nested_account_codes(category_id)
      found = find_in_nested_structure(category_id)
      return [] unless found

      collect_all_codes(found)
    end

    # Build a BalanceSheetSection tree for a top-level category
    # @param account_list [Array<Hash>] List of account hashes with :code, :name, :balance keys
    # @param category_id [Symbol] The top-level category identifier
    # @return [BalanceSheetSection] The root section with nested children
    def build_nested_section(account_list, category_id)
      structure = nested_category_structure(category_id)
      build_section_recursive(account_list, category_id, structure, level: 1)
    end

    private

    # Validate that the section_id exists in GUV_SECTIONS
    def validate_guv_section!(section_id)
      unless GUV_SECTIONS.key?(section_id)
        raise ArgumentError, "Unknown GuV section: #{section_id}. Valid sections: #{GUV_SECTIONS.keys.join(', ')}"
      end
    end

    # Validate that the category_id exists in BALANCE_SHEET_CATEGORIES
    def validate_balance_sheet_category!(category_id)
      unless BALANCE_SHEET_CATEGORIES.key?(category_id)
        raise ArgumentError, "Unknown balance sheet category: #{category_id}. Valid categories: #{BALANCE_SHEET_CATEGORIES.keys.join(', ')}"
      end
    end

    # Expand account ranges into individual account codes
    # @param account_specs [Array<String>] Array of individual codes or ranges (e.g., ["4000", "5000-5999"])
    # @return [Array<String>] Array of individual account codes
    def expand_account_ranges(account_specs)
      result = []

      account_specs.each do |spec|
        if spec.include?("-")
          # It's a range like "4000-4999"
          start_code, end_code = spec.split("-")
          start_num = start_code.to_i
          end_num = end_code.to_i

          (start_num..end_num).each do |num|
            result << num.to_s.rjust(start_code.length, "0")
          end
        else
          # It's an individual account code
          result << spec
        end
      end

      result.uniq.sort
    end

    # Validate that category exists in nested structure
    def validate_nested_category!(category_id)
      valid_aktiva = NESTED_BALANCE_SHEET_CATEGORIES[:aktiva].keys
      valid_passiva = NESTED_BALANCE_SHEET_CATEGORIES[:passiva].keys
      valid_categories = valid_aktiva + valid_passiva

      unless valid_categories.include?(category_id)
        raise ArgumentError, "Unknown nested category: #{category_id}. Valid categories: #{valid_categories.join(', ')}"
      end
    end

    # Find a category in the nested structure (recursive search)
    def find_in_nested_structure(category_id)
      # Search aktiva
      NESTED_BALANCE_SHEET_CATEGORIES[:aktiva].each do |key, data|
        found = search_category_recursive(key, data, category_id)
        return found if found
      end

      # Search passiva
      NESTED_BALANCE_SHEET_CATEGORIES[:passiva].each do |key, data|
        found = search_category_recursive(key, data, category_id)
        return found if found
      end

      nil
    end

    def search_category_recursive(current_key, current_data, target_key)
      return current_data if current_key == target_key

      if current_data[:children]
        current_data[:children].each do |child_key, child_data|
          found = search_category_recursive(child_key, child_data, target_key)
          return found if found
        end
      end

      nil
    end

    # Collect all codes from a structure and its children
    def collect_all_codes(structure)
      codes = structure[:codes] || []

      if structure[:children]
        structure[:children].each_value do |child_data|
          codes.concat(collect_all_codes(child_data))
        end
      end

      expand_account_ranges(codes)
    end

    # Recursively build BalanceSheetSection tree
    def build_section_recursive(account_list, section_key, structure, level:)
      # Get codes for this level only (not children)
      own_codes = expand_account_ranges(structure[:codes] || [])

      # Filter accounts that belong to this level
      own_accounts = account_list.select { |account| own_codes.include?(account[:code]) }

      # Create section
      section = BalanceSheetSection.new(
        section_key: section_key,
        section_name: structure[:name],
        level: level,
        accounts: own_accounts
      )

      # Recursively build children
      if structure[:children]
        structure[:children].each do |child_key, child_data|
          child_section = build_section_recursive(
            account_list,
            child_key,
            child_data,
            level: level + 1
          )
          section.add_child(child_section) unless child_section.empty?
        end
      end

      section
    end
  end
end
