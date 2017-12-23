module CancanConcern
  extend ActiveSupport::Concern

  included do
    helper_method :cancan_disabled?, :cancan_enabled?
  end

  class_methods do
    def cancan_enabled?
      begin
        CanCan::Ability && true
      rescue NameError
        false
      end
    end
  end

  def cancan_enabled?
    self.class.cancan_enabled?
  end

  def cancan_disabled?
    ! self.class.cancan_enabled?
  end
end
