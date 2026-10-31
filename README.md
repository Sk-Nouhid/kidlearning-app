# TinyTrail

TinyTrail is a playful early-learning project with three parts:

- **Child app** (`tinytrail/child_app`) — Flutter app for tracing letters and numbers, playing matching/multiple-choice games, downloading games for offline use, and viewing progress.
- **Teacher portal** (`tinytrail/teacher_portal`) — React + TypeScript studio for creating games, writing questions, uploading media, and publishing games.
- **Backend** (`tinytrail-backend`) — Node.js/Express API backed by PostgreSQL, with JWT teacher authentication and static media uploads.

This repository was produced for a course project. The child app is the primary deliverable; the backend is intentionally kept close to its original state.

## Repository layout

```
kidlearning-app/
├── README.md
├── tinytrail/
│   ├── child_app/          Flutter child application
│   └── teacher_portal/     React/Vite teacher portal
└── tinytrail-backend/      Express API + PostgreSQL schema/migrations
```

## Prerequisites

- Node.js 20+ and npm
- PostgreSQL 14+ (the local development database uses port `5433`)
- Flutter 3.44+ and Dart 3.12+
- Chrome/Edge for Flutter Web, or an Android emulator/device for Android

## Quick start

### 1. Database and backend

Create a PostgreSQL database, then run the schema and migrations in order:

```bash
psql -h localhost -p 5433 -U postgres -d tinytrail_db -f tinytrail-backend/src/db/schema.sql
psql -h localhost -p 5433 -U postgres -d tinytrail_db -f tinytrail-backend/src/db/migrations/001_question_library.sql
psql -h localhost -p 5433 -U postgres -d tinytrail_db -f tinytrail-backend/src/db/migrations/002_migrate_existing_questions.sql
psql -h localhost -p 5433 -U postgres -d tinytrail_db -f tinytrail-backend/src/db/migrations/003_unique_question_prompts.sql
```

Create `tinytrail-backend/.env` (use your own values; do not commit real secrets):

```env
PORT=5000
DB_HOST=localhost
DB_PORT=5433
DB_NAME=tinytrail_db
DB_USER=postgres
DB_PASSWORD=your-local-password
JWT_SECRET=replace-with-a-long-random-value
```

The schema seeds game templates but not a teacher account. For this demo the API compares the stored `password_hash` as plain text, so insert a demo teacher row:

```sql
INSERT INTO teachers (id, login_id, password_hash)
VALUES (1, 'your-teacher-id', 'your-demo-password')
ON CONFLICT (id) DO UPDATE
SET login_id = EXCLUDED.login_id,
    password_hash = EXCLUDED.password_hash;
```

Start the API:

```bash
cd tinytrail-backend
npm install
npm run dev
```

Verify it at `http://localhost:5000/api/health`.

### 2. Teacher portal

```bash
cd tinytrail/teacher_portal
npm install
npm run dev
```

The portal opens at `http://localhost:5173` and calls the API at `http://localhost:5000` by default. Override with `VITE_API_BASE_URL` if needed.

### 3. Child app (Flutter Web)

```bash
cd tinytrail/child_app
flutter pub get
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:5000 \
  --dart-define=TEACHER_PORTAL_URL=http://localhost:5173
```

For a production-style web build:

```bash
flutter build web --release
```

Serve `build/web` with any static file server.

### 4. Child app (Android)

Connect an emulator/device and run:

```bash
cd tinytrail/child_app
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:5000 \
  --dart-define=TEACHER_PORTAL_URL=http://10.0.2.2:5173
```

`10.0.2.2` is the Android emulator's alias for the host machine. Debug builds allow cleartext HTTP for local development; production builds should use HTTPS.

## Features

### Child app

- Letter trail A–Z and number trail 1–20 with finger tracing, pass state, and saved progress.
- Narrow, centered tracing card that fits small screens; uppercase and lowercase are shown, uppercase is traced.
- Swipe or arrow navigation between lessons; finishing the last lesson returns to the trail overview.
- Built-in offline games and teacher-published games.
- Online play, download-for-offline, update detection using content fingerprints, cancellation, and storage-error handling.
- Matching and multiple-choice game types with index-based matching state.
- Progress screen with lessons explored, games played, questions answered, offline saves, separate built-in/teacher histories, and recent scores.
- Friendly network/storage error messages and a startup connectivity check.

### Teacher portal

- Teacher sign-in with show/hide password controls.
- Automatic sign-out when the API returns `401`.
- Create/edit draft games, add/edit/remove questions, and publish with a five-question minimum.
- Preview a game's questions before publishing.
- Reuse questions from the library in a draft.
- Upload images to a media shelf (API support; not yet attachable to questions in the portal).
- Change-password form with show/hide controls.

## API overview

All protected routes require `Authorization: Bearer <token>`.

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/` | No | Service banner |
| GET | `/api/health` | No | Database health check |
| GET | `/api/templates` | No | Available game templates |
| POST | `/api/games` | Yes | Create a draft game |
| GET | `/api/games` | Yes | List all games |
| GET | `/api/games/published` | No | List published games for learners |
| PUT | `/api/games/:gameId` | Yes | Update game details |
| PATCH | `/api/games/:gameId/publish` | Yes | Publish a game |
| DELETE | `/api/games/:gameId` | Yes | Delete a game |
| GET | `/api/games/:gameId/questions` | No | Questions for a game |
| POST | `/api/games/:gameId/questions` | Yes | Add a new question to a game |
| PUT | `/api/games/:gameId/questions/:questionId` | Yes | Edit a game question |
| DELETE | `/api/games/:gameId/questions/:questionId` | Yes | Remove a question from a game |
| GET | `/api/questions` | Yes | Question library |
| POST | `/api/questions` | Yes | Create a library question |
| POST | `/api/questions/games/:gameId/questions/reuse` | Yes | Add a library question to a game |
| POST | `/api/media/upload` | Yes | Upload an image (multipart field `image`) |
| GET | `/api/media` | Yes | List uploaded media |
| POST | `/api/teacher-auth/login` | No | Teacher login (`loginId`, `password`) |
| POST | `/api/teacher-auth/change-password` | Yes | Change password |

Static uploads are served from `/uploads/*`.

## Verification

Run from `tinytrail/child_app`:

```bash
flutter analyze
flutter test
flutter build web --release
```

Results in this environment:

- `flutter analyze`: no issues.
- `flutter test`: 18 tests passed (models, matching/game logic, local storage, API client, tracing, widget navigation/progress).
- `flutter build web --release`: succeeded (`build/web`).
- Teacher portal `npm run build`: succeeded (`tinytrail/teacher_portal/dist`).
- Live API check: `/api/health`, `/api/games/published` (2 games), `/api/templates` (5 templates), and questions for games 4/5 responded successfully.
- Android debug APK: **not produced**. `flutter build apk --debug` could not complete because the Gradle JVM crashed with native out-of-memory errors on this machine. No Android emulator/device was available, so Android runtime behavior is unverified.

## Known limitations / security notes

This is a demo project, not production-ready:

- Teacher passwords are stored and compared as plain text. Use a real password hash (e.g. bcrypt/argon2) before any real deployment.
- `tinytrail-backend/.env` is present in the project. Treat its values as compromised/demo-only and replace them; add `.env` to `.gitignore` before publishing a repository.
- The seed data includes three templates (`picture_question`, `picture_matching`, `voice_to_drawing`) that the child app does not support. The app and portal only handle `matching` and `multiple_choice`.
- The question library supports create/list/reuse but not edit/delete.
- Media can be uploaded, but the portal does not attach media to questions.
- A unique prompt constraint can conflict with copying a question while editing.
- The question create route calls `prompt.trim()` without first checking that `prompt` is a string; a missing prompt can cause a server error.
- `schema.sql` does not create `question_bank`/`game_questions` or seed a teacher; run the migrations and add a demo teacher as described above.
- The child app stores downloaded games and progress locally with Sembast; clearing browser/site data removes them.
- Android HTTP access is enabled for debug builds only. Production builds require HTTPS.
- Teacher sessions are stored in `sessionStorage` for the browser tab and expire after seven days (JWT).

## Useful commands

```bash
# Backend
cd tinytrail-backend && npm run dev

# Teacher portal
cd tinytrail/teacher_portal && npm run dev
cd tinytrail/teacher_portal && npm run build

# Child app
cd tinytrail/child_app
flutter analyze
flutter test
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000
flutter build web --release
```
