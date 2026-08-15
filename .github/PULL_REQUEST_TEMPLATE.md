## Summary

<!-- What does this PR change and why? -->

## Test plan

- [ ] `dart format --output=none --set-exit-if-changed packages example/lib`
- [ ] `flutter analyze` in every touched `packages/*` (and `example` if relevant)
- [ ] `flutter test` in `flutter_reels_composer_core` and/or `flutter_reels_composer_ui` when those packages change
- [ ] Manual: example camera / gallery / export on Android and/or iOS if UI or export changed

## License

- [ ] MIT packages still have **no** dependency on `flutter_reels_composer_gpl` or `flutter_reels_composer_export_gpl`
- [ ] LGPL export still does **not** use `libx264`
- [ ] Changelog updated (package + root) if this is a user-visible change
