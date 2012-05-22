$:.unshift File.join(File.dirname(__FILE__),'..','lib')
require 'rubygems'
require 'test/unit'
require 'active_support/core_ext/string'

module InlineForms
  SPECIAL_COLUMN_TYPES = {}
end

class Dropdown
  attr_accessor :params
  # niet echt convetioneel
  # met require worden de methods in dropdown.rb private
  # het zijn dan private methods van de class Object
  code = File.read '../lib/app/helpers/form_elements/dropdown.rb'
  eval code
end

class ReflectionMock
  def options
    {:foreign_key => :foreign_key_name}
  end
end

class AssociationMock
  def reflection
    ReflectionMock.new
  end
end

class ObjectMock
  def association attribute
    raise "wrong parameter" unless attribute == :attribute
    AssociationMock.new    
  end
  def []= key, value
    @hash ||= {}
    @hash[key] = value
  end
  def [] key
    @hash[key]
  end
end

class DropdownTest < Test::Unit::TestCase
  def test_dropdown_update
    object = ObjectMock.new
    dropdown = Dropdown.new
    dropdown.params = {:_object_mock => {:attribute_id => 1}}
    dropdown.dropdown_update(object, "attribute")
    assert_equal object[:foreign_key_name], 1
  end
end
