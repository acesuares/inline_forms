# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module DnsRecordsHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    def dnsrecords_show(object, attribute)
      out = ""
      [object.a_records,object.template_a_records].flatten.collect do |r|
        out << r.djbdns_line(object.name) + "<br/>"
      end
      raw out
    end
    
    def dnsrecords_edit(object, attribute)
    end
    
    def dnsrecords_update(object, attribute)
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
