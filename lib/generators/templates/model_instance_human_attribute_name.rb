# Wrapper for @model.human_attribute_name -> Model.human_attribute_name
#
class ActiveRecord::Base
  def human_attribute_name(*args)
    self.class.human_attribute_name(*args)
  end
end
