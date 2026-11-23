# frozen_string_literal: true

module InlineForms
  # A field got a value it did not offer (a dropdown or check_list id outside
  # the records the user may read). The record stays invalid while that value
  # is on it, whoever saves it: the engine's create / update, or a host's own.
  #
  # The model's own validations run first, so a model that refuses the value
  # with a message of its own keeps that message; :inclusion is only added
  # when the attribute, or its foreign key, has no error yet.
  module RefusedValues
    def self.add(object, attribute)
      object.extend(self)
      object.inline_forms_refused_values << attribute.to_sym
    end

    def inline_forms_refused_values
      @inline_forms_refused_values ||= Set.new
    end

    def valid?(...)
      super
      inline_forms_refused_values.each do |attribute|
        foreign_key = self.class.reflect_on_association(attribute)&.foreign_key
        next if errors.include?(attribute) || (foreign_key && errors.include?(foreign_key.to_sym))

        errors.add(attribute, :inclusion)
      end
      errors.empty?
    end
    alias_method :validate, :valid?
  end
end
