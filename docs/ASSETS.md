# Assets and attribution

Every bundled asset is listed here with its origin and license. Nothing is
downloaded at runtime.

| Asset | Origin | License |
| --- | --- | --- |
| `assets/fonts/inter/Inter-{Regular,Medium,SemiBold,Bold}.ttf` | Inter typeface by The Inter Project Authors (rsms/inter) | SIL Open Font License 1.1 – full text in `assets/fonts/inter/OFL.txt`, also registered with Flutter's license page (Settings → Credits & licenses → Open-source licenses) |
| `assets/audio/{tick,go,rest,complete}.wav` | Sine-wave tones synthesized for this project by `tool/generate_tones.dart` | Original work, no third-party rights |
| Exercise demonstrations (`figure://<exerciseId>`) | Stick-figure animations drawn in code by `lib/features/exercise_media/` (pose library, interpolation and painter) | Original work, no third-party rights |
| Material Icons | Bundled with the Flutter SDK | Apache License 2.0 (included in the licenses Flutter generates for the app) |
| `assets/data/**` | Exercise, workout, plan, article and tip text written for this project | Original work – see [CONTENT.md](CONTENT.md) for review status |
| Android/iOS launcher icons | **Flutter's default template icon** | Placeholder – must be replaced before release |

`assets/images/` and `assets/animations/` are empty placeholders.

## Exercise demonstrations – known limitation

No licensed photos, videos or professionally produced animations were
available, and none were invented or downloaded. Instead every one of the
88 exercises has a procedurally drawn, looping stick-figure animation
built from hand-authored key poses.

These illustrations:

- show the general shape and rhythm of each movement and were reviewed
  visually as rendered contact sheets during development;
- are **simplified**: no joint-angle accuracy guarantees, no depth cues
  beyond simple foreshortening, no muscles, faces or equipment detail;
- have **not** been reviewed by a qualified fitness professional.

Every exercise also has written setup, steps, breathing cues, common
mistakes, easier and harder options and cautions, which carry the actual
instruction. The exercise screen labels the figure as a simplified
illustration.

Replacing them is a release blocker if the app is to be marketed as having
professional demonstrations (see [RELEASE_BLOCKERS.md](RELEASE_BLOCKERS.md)).

## Adding real media later

The media pipeline already supports bundled Lottie animations
(`assets/…json`) and images in addition to `figure://` sequences. For each
new file:

1. Add the file under `assets/` and to `pubspec.yaml`.
2. Set the exercise's `mediaPath` and add an `attribution` object
   (`source`, `license`, optional `author` and `notes`, e.g. whether it was modified).
3. Add a row to the table above.
4. Only use media whose license permits bundling in a distributed app and
   which you can document. Do not add media with unknown origin.
