# -*- encoding : utf-8 -*-
class GeoCodeCuracao
  attr_accessor :street, :neighbourhood, :zone
  
  class Zone < ActiveRecord::Base
    set_table_name "Zones"
    alias_attribute :name, :NAME
  end

  class Neighbourhood < ActiveRecord::Base
    set_table_name "Buurten"
    alias_attribute :name, :NAME
  end

  class Street < ActiveRecord::Base
    set_table_name "Straatcode"
    alias_attribute :name, :NAME
  end

  def initialize(geo_code_curacao)
    return nil if geo_code_curacao.nil?
    decoded = geo_code_curacao.to_s.scan(/\d\d/)
    zone_code = decoded[0]
    neighbourhood_code = decoded[1]
    street_code = decoded[2]
    self.street = Street.find_by_ZONECODE_and_NBRHCODE_and_STREETCODE(zone_code,neighbourhood_code,street_code)
    self.neighbourhood = Neighbourhood.find_by_ZONECODE_and_NBRHCODE(zone_code,neighbourhood_code) if self.street
    self.zone = Zone.find_by_ZONECODE(zone_code) if self.street
  end

  def valid?
    not self.street.nil?
  end

  def presentation
    "#{street.name}, #{zone.name}"
  end

  def self.lookup(term)
    street = term.gsub(/\\/, '\&\&').gsub(/'/, "''")
    sql = "select CONCAT( CONCAT_WS( ', ', S.NAME, B.NAME, Z.NAME), ' (', LPAD( S.ZONECODE, 2, '0' ), LPAD( S.NBRHCODE, 2, '0' ), LPAD( S.STREETCODE, 2, '0' ), ')' ) 
              FROM Straatcode S,  Buurten B, Zones Z
              WHERE 
                  B.RECORDTYPE='NBRHOOD'
              AND S.ZONECODE=Z.ZONECODE
              AND B.ZONECODE=Z.ZONECODE
              AND S.ZONECODE=B.ZONECODE
              AND S.NBRHCODE = B.NBRHCODE
              AND S.NAME LIKE '#{street}'
              ORDER BY S.NAME"
    q = []
    ActiveRecord::Base.connection.execute(sql).to_a.each do |r|
      q << { :label => r[0] }
    end
    q.to_json.html_safe
  end
end
