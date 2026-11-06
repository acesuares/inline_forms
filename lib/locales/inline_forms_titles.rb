# frozen_string_literal: true

# The gem's title keys, resolved to the application's name
# (InlineForms.application_title) instead of a placeholder. Lambdas, so a
# host view that calls a key bare gets the real name too. A host translation
# of the same key still wins: the host's locale files load after the gem's.
title = ->(_key, **_options) { InlineForms.application_title }
welcome = ->(_key, **_options) { I18n.t("inline_forms.devise.welcome_to", name: InlineForms.application_title) }
keys = {
  inline_forms: {
    general: { application_title: title },
    devise: { title_for_devise: title, welcome: welcome }
  }
}

{ en: keys, nl: keys }
