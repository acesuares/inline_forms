# frozen_string_literal: true

# Mirrors the initializer the installer writes into generated apps
# (installer_core.rb): PaperTrail serializes object/object_changes as YAML,
# and Psych safe-loading needs these classes permitted or version.changeset /
# version.reify silently degrade (empty changeset) or raise.
permitted = [
  Symbol,
  Date,
  Time,
  BigDecimal,
  ActiveSupport::TimeWithZone,
  ActiveSupport::TimeZone,
  ActiveSupport::HashWithIndifferentAccess
]

%w[
  ActiveRecord::Type::Time::Value
  ActiveRecord::Type::Date::Value
  ActiveRecord::Type::DateTime::Value
].each do |const_name|
  klass = const_name.safe_constantize
  permitted << klass if klass
end

Rails.application.config.active_record.yaml_column_permitted_classes ||= []
Rails.application.config.active_record.yaml_column_permitted_classes |= permitted
ActiveRecord.yaml_column_permitted_classes |= Rails.application.config.active_record.yaml_column_permitted_classes
