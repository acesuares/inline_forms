class InlineFormsCreateViewForTranslations < ActiveRecord::Migration

execute 'CREATE VIEW translations  ( locale, thekey, value, interpolations, is_proc )
              AS
              SELECT L.name, K.name, T.value, T.interpolations, T.is_proc
              FROM if_keys K, if_locales L, if_translations T
              WHERE T.if_key_id = K.id AND T.i_locale_id = L.id '

  end

  def self.down
    execute 'DROP VIEW translations'
  end


end
