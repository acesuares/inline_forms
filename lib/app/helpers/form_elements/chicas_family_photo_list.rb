# -*- encoding : utf-8 -*-
# not needed here, since this is only used in the views InlineForms::SPECIAL_COLUMN_TYPES[:info]=:string

# this will NOT stay in inline_forms, it belongs in an app.

def chicas_family_photo_list_show(object, attribute)
  # the attribute should be like members_photos
  # then it will look for object.family.members.photos
  # I know it's crappy.
  members, photos = attribute.to_s.split('_')
  photo_list = {}
  object.family.send(members).each do |member|
    member.send(photos).each do |photo|
      photo_list[photo.rating] ||= []
      photo_list[photo.rating] << photo
    end
  end
  out = ''
  if photo_list.empty?
    out = "<div class='row #{cycle('odd', 'even')}'>no photos</div>"
  else
    out << "<div class='row #{cycle('odd', 'even')}'>"
    photo_list.sort.reverse.each do |rating, photos|
      photos.each do |photo|
        out << image_tag(photo.image.url(:thumb), 
        	onclick: "this.src='#{photo.image.url(:palm)}'", 
        	onmouseout: "this.src='#{photo.image.url(:thumb)}'")
      end
    end
    out << '</div>'
  end
  out.html_safe
end
