# frozen_string_literal: true

require_relative "../integration_test_helper"

# The engine's validators (app/validators) add their error with
# errors.add. Until 8.1.81 three of them did `errors[attribute] << …`, which
# Rails 7.0 and later throw away: the record stayed valid.
class ValidatorsTest < InlineFormsIntegrationTestCase
  class Contact
    include ActiveModel::Validations

    attr_accessor :email, :phone, :sex

    validates :email, is_email_address: true, allow_nil: true
    validates :phone, is_curacao_phone: true, allow_nil: true
    validates :sex, must_be_a_value: true, allow_nil: true

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
