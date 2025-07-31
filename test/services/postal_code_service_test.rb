require "test_helper"

class PostalCodeServiceTest < ActiveSupport::TestCase
  def setup
    @postal_service = PostalCodeService.new
  end

  # US ZIP Code Tests
  test "should validate US 5-digit ZIP codes" do
    valid_zips = ["12345", "90210", "10001", "33101"]
    
    valid_zips.each do |zip|
      result = @postal_service.validate_postal_code(zip)
      assert result[:valid], "ZIP code #{zip} should be valid"
      assert_equal "US", result[:country]
      assert_equal zip, result[:postal_code]
      assert_nil result[:error]
    end
  end

  test "should validate US ZIP+4 codes" do
    valid_zip4s = ["12345-6789", "90210-1234", "10001-0001"]
    
    valid_zip4s.each do |zip4|
      result = @postal_service.validate_postal_code(zip4)
      assert result[:valid], "ZIP+4 code #{zip4} should be valid"
      assert_equal "US", result[:country]
      assert_equal zip4, result[:postal_code]
      assert_nil result[:error]
    end
  end

  test "should reject invalid US ZIP codes" do
    invalid_zips = ["1234", "123456", "1234A", "ABCDE", "12345-123", "12345-12345"]
    
    invalid_zips.each do |invalid_zip|
      result = @postal_service.validate_postal_code(invalid_zip)
      assert_not result[:valid], "ZIP code #{invalid_zip} should be invalid"
      assert_nil result[:country]
      assert_nil result[:postal_code]
      assert_equal "Invalid postal code format", result[:error]
    end
  end

  # Canadian Postal Code Tests
  test "should validate Canadian postal codes" do
    valid_canadian = ["A1A 1A1", "B2B 2B2", "C3C3C3", "D4D-4D4", "E5E 5E5"]
    
    valid_canadian.each do |postal|
      result = @postal_service.validate_postal_code(postal)
      assert result[:valid], "Canadian postal code #{postal} should be valid"
      assert_equal "CA", result[:country]
      assert_not_nil result[:postal_code]
      assert_nil result[:error]
    end
  end

  test "should format Canadian postal codes correctly" do
    # Test that Canadian postal codes are formatted as A1A 1A1
    result = @postal_service.validate_postal_code("A1A1A1")
    assert result[:valid]
    assert_equal "A1A 1A1", result[:postal_code]
    
    result = @postal_service.validate_postal_code("B2B-2B2")
    assert result[:valid]
    assert_equal "B2B 2B2", result[:postal_code]
  end

  test "should reject invalid Canadian postal codes" do
    invalid_canadian = ["1A1 A1A", "A1A1A", "A1A1A1A", "123 456", "ABC DEF"]
    
    invalid_canadian.each do |invalid_postal|
      result = @postal_service.validate_postal_code(invalid_postal)
      assert_not result[:valid], "Canadian postal code #{invalid_postal} should be invalid"
      assert_nil result[:country]
      assert_nil result[:postal_code]
      assert_equal "Invalid postal code format", result[:error]
    end
  end

  # Address Extraction Tests
  test "should extract US ZIP codes from addresses" do
    addresses_with_zips = [
      { address: "123 Main St, New York, NY 10001", expected: "10001" },
      { address: "456 Oak Ave, Los Angeles, CA 90210-1234", expected: "90210-1234" },
      { address: "789 Pine Rd, Miami, FL 33101", expected: "33101" }
    ]
    
    addresses_with_zips.each do |test_case|
      result = @postal_service.extract_postal_code_from_address(test_case[:address])
      assert_nil result[:error]
      assert_equal test_case[:expected], result[:postal_code]
    end
  end

  test "should extract Canadian postal codes from addresses" do
    addresses_with_postals = [
      { address: "123 Main St, Toronto, ON A1A 1A1", expected: "A1A 1A1" },
      { address: "456 Oak Ave, Vancouver, BC B2B2B2", expected: "B2B 2B2" },
      { address: "789 Pine Rd, Montreal, QC C3C-3C3", expected: "C3C 3C3" }
    ]
    
    addresses_with_postals.each do |test_case|
      result = @postal_service.extract_postal_code_from_address(test_case[:address])
      assert_nil result[:error]
      assert_equal test_case[:expected], result[:postal_code]
    end
  end

  test "should handle addresses without postal codes" do
    addresses_without_postals = [
      "123 Main St, New York, NY",
      "456 Oak Ave, Los Angeles, CA",
      "789 Pine Rd, Toronto, ON"
    ]
    
    addresses_without_postals.each do |address|
      result = @postal_service.extract_postal_code_from_address(address)
      assert_nil result[:postal_code]
      assert_equal "No valid postal code found in address", result[:error]
    end
  end

  # Combined Validation and Extraction Tests
  test "should validate and extract US ZIP codes from addresses" do
    test_cases = [
      {
        address: "123 Main St, New York, NY 10001",
        expected_postal: "10001",
        expected_country: "US"
      },
      {
        address: "456 Oak Ave, Los Angeles, CA 90210-1234",
        expected_postal: "90210-1234",
        expected_country: "US"
      }
    ]
    
    test_cases.each do |test_case|
      result = @postal_service.validate_and_extract_postal_code(test_case[:address])
      assert result[:valid]
      assert_equal test_case[:expected_country], result[:country]
      assert_equal test_case[:expected_postal], result[:postal_code]
      assert_nil result[:error]
    end
  end

  test "should validate and extract Canadian postal codes from addresses" do
    test_cases = [
      {
        address: "123 Main St, Toronto, ON A1A 1A1",
        expected_postal: "A1A 1A1",
        expected_country: "CA"
      },
      {
        address: "456 Oak Ave, Vancouver, BC B2B2B2",
        expected_postal: "B2B 2B2",
        expected_country: "CA"
      }
    ]
    
    test_cases.each do |test_case|
      result = @postal_service.validate_and_extract_postal_code(test_case[:address])
      assert result[:valid]
      assert_equal test_case[:expected_country], result[:country]
      assert_equal test_case[:expected_postal], result[:postal_code]
      assert_nil result[:error]
    end
  end

  test "should handle invalid addresses" do
    invalid_addresses = [
      "123 Main St, New York, NY",
      "456 Oak Ave, Los Angeles, CA",
      "789 Pine Rd, Toronto, ON",
      "",
      nil
    ]
    
    invalid_addresses.each do |address|
      result = @postal_service.validate_and_extract_postal_code(address)
      assert_not result[:valid]
      assert_nil result[:country]
      assert_nil result[:postal_code]
      assert_not_nil result[:error]
    end
  end

  # Edge Cases and Normalization Tests
  test "should handle postal codes with extra spaces" do
    result = @postal_service.validate_postal_code(" 12345 ")
    assert result[:valid]
    assert_equal "12345", result[:postal_code]
    
    result = @postal_service.validate_postal_code(" A1A 1A1 ")
    assert result[:valid]
    assert_equal "A1A 1A1", result[:postal_code]
  end

  test "should handle case insensitive postal codes" do
    result = @postal_service.validate_postal_code("a1a 1a1")
    assert result[:valid]
    assert_equal "A1A 1A1", result[:postal_code]
    
    result = @postal_service.validate_postal_code("b2b2b2")
    assert result[:valid]
    assert_equal "B2B 2B2", result[:postal_code]
  end

  test "should handle empty and nil inputs" do
    empty_inputs = ["", nil, "   "]
    
    empty_inputs.each do |input|
      result = @postal_service.validate_postal_code(input)
      assert_not result[:valid]
      assert_equal "Postal code cannot be empty", result[:error]
      
      result = @postal_service.extract_postal_code_from_address(input)
      assert_nil result[:postal_code]
      assert_equal "Address cannot be empty", result[:error]
    end
  end

  test "should handle addresses with multiple potential postal codes" do
    # Should extract the first valid postal code found
    address = "123 Main St, New York, NY 10001, but also 90210 somewhere"
    result = @postal_service.extract_postal_code_from_address(address)
    assert_equal "10001", result[:postal_code]
  end

  test "should normalize addresses properly" do
    address = "  123  Main   St,   New   York,   NY   10001  "
    result = @postal_service.validate_and_extract_postal_code(address)
    assert result[:valid]
    assert_equal "10001", result[:postal_code]
  end
end 