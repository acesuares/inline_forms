# frozen_string_literal: true

require_relative "../integration_test_helper"

# The engine's validators (app/validators) add their error with
# errors.add. Until 8.1.81 three of them did `errors[attribute] << …`, which
# Rails 7.0 and later throw away: the record stayed valid. Since 8.1.82 a
# blank value is left to presence:.
class ValidatorsTest < InlineFormsIntegrationTestCase
  class Contact
    include ActiveModel::Validations

    attr_accessor :email, :phone, :sex

    validates :email, is_email_address: true
    validates :phone, is_curacao_phone: true
    validates :sex, must_be_a_value: true

    def initialize(**attributes) = attributes.each { |name, value| public_send("#{name}=", value) }

    def inline_forms_attribute_list = [ [ :sex, :radio_button, { 1 => "f", 2 => "m" } ] ]
  end

  def errors_for(**attributes)
    contact = Contact.new(**attributes)
    contact.valid?
    contact.errors
  end

  test "is_email_address refuses a wrong address and accepts a right one" do
    assert_equal [ "is not a valid email address." ], errors_for(email: "x")[:email]
    assert_empty errors_for(email: "ann@example.com")[:email]
  end

  test "is_curacao_phone refuses a wrong number and accepts a right one" do
    assert_equal [ "is geen geldig Curaçao telefoon nummer." ], errors_for(phone: "12")[:phone]
    assert_empty errors_for(phone: "6781256")[:phone]
  end

  test "must_be_a_value refuses a value the list does not have" do
    assert_equal [ "is geen geldige keuze." ], errors_for(sex: 3)[:sex]
    assert_empty errors_for(sex: 2)[:sex]
  end

  test "a blank value is left to presence:, without allow_nil" do
    [ nil, "", "  " ].each do |blank|
      assert_empty errors_for(email: blank, phone: blank)[:email], "email #{blank.inspect}"
      assert_empty errors_for(email: blank, phone: blank)[:phone], "phone #{blank.inspect}"
    end
    assert_empty errors_for(sex: nil)[:sex]
    assert_empty errors_for(sex: "")[:sex]
    assert_equal [ "is geen geldige keuze." ], errors_for(sex: 0)[:sex], "0 is a value, and not in the list"
  end

  test "a message: option replaces the validator's own" do
    contact_class = Class.new(Contact) do
      def self.name = "MessageContact"
      validates :email, is_email_address: { message: "own message" }
    end
    contact = contact_class.new(email: "x")

    refute contact.valid?
    assert_includes contact.errors[:email], "own message"
  end
end
