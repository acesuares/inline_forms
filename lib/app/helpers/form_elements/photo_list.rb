# -*- encoding : utf-8 -*-
# not needed here, since this is only used in the views InlineForms::SPECIAL_COLUMN_TYPES[:info]=:string

# this will NOT stay in inline_forms, it belongs in an app.

def chicas_photo_list_show(object, attribute)
  # the attribute should be like members_photos
  # then it will look for object.members.photos
  # I know it's crappy.
  members, photos = attribute.to_s.split('_')
  thumbnail_list = {}
  object.send(members).each do |member|
    member.send(photos).each do |photo|
      thumbnail_list[photo.rating] ||= []
      thumbnail_list[photo.rating] << photo.image.url(:thumb)
    end
  end
  out = ''
  out = "<div class='row #{cycle('odd', 'even')}'>no photos</div>" if thumbnail_list.empty?
  unless thumbnail_list.empty?
    out << "<div class='row #{cycle('odd', 'even')}'>"
    thumbnail_list.sort.reverse.each do |rating, thumbnails|
      thumbnails.each do |thumbnail|
        out << image_tag(thumbnail)
      end
    end
    out << '</div>'
  end
  out.html_safe
end
