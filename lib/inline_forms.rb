raise 'hell'
 ;ak ;skdad


module InlineForms
  extend ActiveSupport::Concern
    
  module ClassMethods
    def find_by_tags()
      raise 'hello'
    end
  end

  module InstanceMethods
    def snier()
      raise 'mellow'
    end
  end 
end

class ActiveRecord::Base
  include InlineForms
end
                                           