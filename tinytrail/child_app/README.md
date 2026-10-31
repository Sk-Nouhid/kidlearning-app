# TinyTrail child app

The child-facing Flutter app. Children trace letters and numbers, play learning games from their teacher, download games for offline use, and follow their progress. The UI is designed for small screens and a pastel, early-years style.

## Run

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:5000 \
  --dart-define=TEACHER_PORTAL_URL=http://localhost:5173
```

For Android emulators, use `http://10.0.2.2:5000` and `http://10.0.2.2:5173`. Debug builds allow cleartext HTTP for local development.

Build for the web:

```bash
flutter build web --release
```

## Configuration

Both URLs are compile-time values in `lib/config.dart`:

| Define | Default |
| --- | --- |
| `API_BASE_URL` | `http://localhost:5000` |
| `TEACHER_PORTAL_URL` | `http://localhost:5173` |

## Project structure

| File | Responsibility |
| --- | --- |
| `lib/main.dart` | App shell, navigation, lessons, games, progress UI |
| `lib/api_service.dart` | Published games, question loading, media downloads, friendly errors |
| `lib/local_store.dart` | Sembast persistence for downloads and progress |
| `lib/models.dart` | Games, questions, bundles, snapshots, scoring |
| `lib/game_logic.dart` | Matching state, lesson clamping, progress keys |
| `lib/tracing.dart` | Letter/number guides and trace coverage |
| `lib/config.dart` | API and teacher-portal URL configuration |
| `lib/database_factory_*.dart` | Platform Sembast factories (IO, web, stub) |
| `test/` | Unit and widget tests |

## Testing

```bash
flutter analyze
flutter test
```

The suite covers the API client, persisted downloads/progress, game scoring, matching state, tracing evaluation, model round-trips, and widget navigation to lessons and progress.

## Notes

- Only `matching` and `multiple_choice` teacher games are playable.
- Downloaded games are stored in Sembast (`tinytrail.db` on mobile, IndexedDB on web). Clearing site/app data removes them.
- No Android emulator/device was available in the development environment; Android runtime behavior is unverified. A debug APK build was attempted but failed because the Gradle JVM ran out of native memory on the build machine.
