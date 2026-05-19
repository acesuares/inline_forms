# frozen_string_literal: true

require "fileutils"
require "active_support/core_ext/string/inflections"

root = File.expand_path("..", __dir__)
src = File.join(root, "app/helpers/form_elements")
dst = File.join(root, "app/helpers/inline_forms/form_elements")
registry = {}

Dir.chdir(src)
Dir.glob("*.rb").sort.each do |basename|
  content = File.read(basename)
  content.scan(/InlineForms::SPECIAL_COLUMN_TYPES\[:(\w+)\]\s*=\s*:(\w+)/) do |k, v|
    registry[k.to_sym] = v.to_sym
  end

  body = content.lines.reject do |l|
    l =~ /InlineForms::SPECIAL_COLUMN_TYPES/ ||
      l =~ /^#.*SPECIAL_COLUMN_TYPES/ ||
      l =~ /^#\s*-*\s*encoding/
  end.join
  body = body.strip
  next if body.empty?

  mod = File.basename(basename, ".rb").camelize + "Helper"
  out = <<~RUBY
    # -*- encoding : utf-8 -*-
    module InlineForms
      module FormElements
        module #{mod}
          module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    #{body.gsub(/^/, "    ")}
          INLINE_FORMS_FORM_ELEMENT
        end
      end
    end
  RUBY

  FileUtils.mkdir_p(dst)
  File.write(File.join(dst, "#{File.basename(basename, '.rb')}_helper.rb"), out)
end

registry_path = File.join(root, "lib/inline_forms/form_element_registry.rb")
entries = registry.map { |k, v| "      #{k.inspect} => #{v.inspect}," }.join("\n")
File.write(registry_path, <<~RUBY)
  # frozen_string_literal: true

  module InlineForms
    module FormElementRegistry
      ENTRIES = {
  #{entries}
      }.freeze

      def self.apply!
        SPECIAL_COLUMN_TYPES.merge!(ENTRIES)
      end
    end
  end
RUBY

puts "Migrated #{Dir.glob(File.join(dst, '*_helper.rb')).size} helpers"
