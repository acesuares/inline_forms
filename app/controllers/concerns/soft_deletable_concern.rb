module SoftDeletable
  extend ActiveSupport::Concern

# you need to put this in the model:
#  include SoftDeletable
#  enum deleted: { active: 1, deleted: 2 }

# you need a migration like this:
# class AddDeletedAtColumnToUser < ActiveRecord::Migration[6.0]
#   def change
#     add_column :users, :deleted_at, :datetime, default: nil
#     add_column :users, :deleted, :integer, default: 1
#     add_column :users, :deleted_by, :integer, default: nil
#   end
# end

  def soft_deletable?
    true
  end

  def soft_delete(current_user)
    deleted = 2
    deleter = current_user
    deleted_at = Time.current
    save
  end

  def soft_restore
    deleted = 1
    deleted_by = nil
    deleted_at = nil
    save
  end

end
