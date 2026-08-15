# Publishing to pub.dev

Packages are **not published yet**. This is the intended order once maintainers
are ready. Do not claim packages exist on pub.dev until `pub.dev/packages/<name>`
returns 200.

## Order (core first)

Later packages depend on hosted `^0.2.0` of earlier ones. Publish and wait for
the public index before the next `flutter pub publish`.

1. **`flutter_reels_composer_core`** — no camera, no FFmpeg, fewest deps
2. **`flutter_reels_composer_ui`** — depends on core
3. **`flutter_reels_composer_local`** — depends on core
4. **`flutter_reels_composer_export_lgpl`** — depends on core + LGPL FFmpeg Kit
5. **`flutter_reels_composer`** — MIT facade (depends on 1–4)
6. **`flutter_reels_composer_export_gpl`** — GPL; publish only if you intend
   to distribute GPL on pub.dev
7. **`flutter_reels_composer_gpl`** — GPL facade (depends on 1–3 + 6)

Never publish GPL adapters as MIT. Keep `license:` in each `pubspec.yaml`
accurate (`MIT` vs `GPL-3.0`).

## Checklist per package

From the package directory:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test   # where tests exist
flutter pub publish --dry-run
flutter pub publish
```

Also:

- `version` in `pubspec.yaml` matches `CHANGELOG.md`
- `homepage` / `repository` / `issue_tracker` point at
  https://github.com/allochat/flutter_reels_composer
- README states Android + iOS only
- MIT facade README links LGPL vs GPL docs
- `pubspec_overrides.yaml` is for local dev; pub.dev uses hosted deps
- Example stays `publish_to: none`
- Workspace root stays `publish_to: none`

## After publish

Host apps can drop Git `dependency_overrides` and use:

```yaml
dependencies:
  flutter_reels_composer: ^0.2.0
```

Update the root README so it no longer says packages are unpublished.

## Versioning

This monorepo ships packages in lockstep at **0.2.0**. If you later split
versions, bump dependents and republish in the same order.
