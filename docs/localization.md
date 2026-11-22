# Localization

Every player-facing sentence is written `L["The whole English sentence"]`. English is the key, so a missing translation shows English and never raises an error.

- Use the full sentence as the key. Do not build a sentence from parts, and do not use a variable as a key. `tests/test_locale.lua` rejects both.
- Put values in with `%s` and `%d` placeholders: `L["Started %s."]:format(id)`.
- Debug output (`/wtt log`, the debug lines) stays English. Translators do not need it.
- A translation file goes in `TestThat/Locales/<locale>.lua`, loads after `enUS.lua`, returns at once unless `GetLocale()` is that locale, and assigns `ns.L["English sentence"] = "Translation"`. List it in both TOC files.
- Keep control labels and the words in help text identical to the labels, as in `DESIGN.md` (ASD-STE100 rules).
