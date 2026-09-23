# Animated icons

`lib/core/widgets/anim_icon.dart` draws its icons in code: `AnimIcon(AnimShape.bag)`
behaves like `Icon`, taking size and colour from the ambient `IconTheme`.
`AnimIconButton` replays the drawing on every press.

They are hand-authored rather than pulled from Lordicon or LottieFiles for three
reasons: no licence to honour, nothing to download at runtime, and they follow
the app's own colours and `Motion` tokens instead of a fixed palette baked into
a file.

## Reduced motion

`MediaQuery.disableAnimations` settles every icon on its finished frame. Reduced
motion means no movement, never a missing icon.

## Reviewing a change

A painter is only correct if it reads right, and no assertion can tell you that.
Render the sheet and look at it:

    flutter test tool/render_icons.dart
    open /tmp/anim_icons.png

Each row is one shape, each column a point in its run. `ICON_SHEET=<path>`
writes somewhere else.

## Adding a Lottie file later

Nothing here depends on one, but if a licensed `.json` is bought:

1. `flutter pub add lottie`
2. Drop the file in `assets/icons/` and declare it in `pubspec.yaml`
3. Wrap it so reduced motion still shows a still frame, the way `AnimIcon` does

Prefer extending `AnimShape` for anything used more than once — a code-drawn icon
costs nothing to ship and cannot go missing from an asset bundle.
