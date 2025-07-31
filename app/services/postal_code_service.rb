class PostalCodeService
  # US ZIP code patterns (5 digits or 5+4 format)
  US_ZIP_PATTERNS = [
    /^\d{5}$/,                    # 12345
    /^\d{5}-\d{4}$/              # 12345-6789
  ]

  # Canadian postal code patterns (A1A 1A1 format)
  CANADA_POSTAL_PATTERNS = [
    /^[A-Za-z]\d[A-Za-z]\s?\d[A-Za-z]\d$/,  # A1A 1A1 or A1A1A1
    /^[A-Za-z]\d[A-Za-z]-\d[A-Za-z]\d$/      # A1A-1A1
  ]

  def validate_and_extract_postal_code(address)
    # Normalize the address
    normalized_address = normalize_address(address)
    
    # Extract and validate postal code
    extract_and_validate_postal_code(normalized_address)
  end

  def validate_postal_code(postal_code)
    return { valid: false, country: nil, postal_code: nil, error: "Postal code cannot be empty" } if postal_code.blank?
    
    normalized_postal = normalize_postal_code(postal_code)
    
    # Check US ZIP codes
    if US_ZIP_PATTERNS.any? { |pattern| normalized_postal.match?(pattern) }
      return {
        valid: true,
        country: 'US',
        postal_code: normalized_postal,
        error: nil
      }
    end
    
    # Check Canadian postal codes
    if CANADA_POSTAL_PATTERNS.any? { |pattern| normalized_postal.match?(pattern) }
      # Format Canadian postal code properly (A1A 1A1)
      formatted_postal = format_canadian_postal_code(normalized_postal)
      return {
        valid: true,
        country: 'CA',
        postal_code: formatted_postal,
        error: nil
      }
    end
    
    {
      valid: false,
      country: nil,
      postal_code: nil,
      error: "Invalid postal code format"
    }
  end

  def extract_postal_code_from_address(address)
    return { postal_code: nil, error: "Address cannot be empty" } if address.blank?
    
    normalized_address = normalize_address(address)
    
    # Extract US ZIP codes
    us_zip_match = normalized_address.match(/\b\d{5}(?:-\d{4})?\b/)
    if us_zip_match
      return {
        postal_code: us_zip_match[0],
        error: nil
      }
    end
    
    # Extract Canadian postal codes
    canada_postal_match = normalized_address.match(/\b[A-Za-z]\d[A-Za-z][\s-]?\d[A-Za-z]\d\b/)
    if canada_postal_match
      postal_code = format_canadian_postal_code(canada_postal_match[0])
      return {
        postal_code: postal_code,
        error: nil
      }
    end
    
    {
      postal_code: nil,
      error: "No valid postal code found in address"
    }
  end

  private

  def extract_and_validate_postal_code(address)
    # First try to extract postal code from address
    extraction_result = extract_postal_code_from_address(address)
    
    if extraction_result[:error]
      return {
        valid: false,
        country: nil,
        postal_code: nil,
        error: extraction_result[:error]
      }
    end
    
    # Validate the extracted postal code
    validation_result = validate_postal_code(extraction_result[:postal_code])
    
    if validation_result[:valid]
      return {
        valid: true,
        country: validation_result[:country],
        postal_code: validation_result[:postal_code],
        error: nil,
        address: address
      }
    else
      return {
        valid: false,
        country: nil,
        postal_code: nil,
        error: validation_result[:error]
      }
    end
  end

  def normalize_address(address)
    address.to_s.strip.gsub(/\s+/, ' ').upcase
  end

  def normalize_postal_code(postal_code)
    postal_code.to_s.strip.upcase.gsub(/\s+/, '')
  end

  def format_canadian_postal_code(postal_code)
    # Remove all spaces and hyphens, then format as A1A 1A1
    cleaned = postal_code.gsub(/[\s-]/, '').upcase
    if cleaned.match?(/^[A-Z]\d[A-Z]\d[A-Z]\d$/)
      "#{cleaned[0..2]} #{cleaned[3..5]}"
    else
      postal_code
    end
  end

end 