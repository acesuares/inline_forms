class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # Wrapper for @model.human_attribute_name -> Model.human_attribute_name
  def human_attribute_name(*args)
    self.class.human_attribute_name(*args)
  end

end
