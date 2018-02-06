PaperTrail.config.track_associations = false

PaperTrail::Version.class_eval do
  def author
    User.find(whodunnit) if whodunnit
  end
end
