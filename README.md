# Svesnote

A cross-platform voice journaling app: record a note, sync it to the cloud, and browse your entries on a calendar.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3FCF8E?style=flat-square&logo=supabase&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=flat-square&logo=postgresql&logoColor=white)

<!-- TODO: add screenshot -->

## Overview

Svesnote is a Flutter app for keeping a spoken journal. Users sign in, tap a single record button, and each voice note is saved locally, uploaded to Supabase Storage, and indexed in Postgres. A calendar view shows how active each day was. A separate **Processes** module tracks ongoing personal commitments, such as habits or goals, that are either time-limited or open-ended. Supabase is the whole backend (auth, database, file storage), so there is no custom server to run.

## Key features

- **Email/password auth** with a 3-step sign-up flow (email, then password, then username). The session persists across restarts.
- **One-tap voice recording** (AAC/M4A) from a docked centre button, with a live duration timer and microphone permission handling.
- **Cloud sync**: each recording is uploaded to a per-user, per-day path in Supabase Storage and linked to a database entry.
- **Secure playback** streamed through short-lived signed URLs (5 minutes), so the storage bucket never has to be public.
- **Calendar heatmap**: a month view built on `table_calendar` that colours each day by entry count. Tap a day to filter the list.
- **Bulk delete**: long-press to enter selection mode, multi-select, confirm, and both the database rows and the audio files are removed.
- **Processes**: create, edit, pause/resume, and delete commitments, with an optional end date. Expired processes are flagged.
- **Pull-to-refresh**, loading and error states, plus a profile page.

Analysis, statistics, and settings screens are scaffolded as "coming soon" placeholders. The `transcript` column exists in the schema but is not populated yet.

## Tech stack

| Layer | Technology |
|---|---|
| UI | Flutter (Material), Dart SDK ^3.10 |
| Auth / DB / Storage | Supabase (`supabase_flutter`): Auth, PostgreSQL, Storage |
| Audio | `flutter_sound` (recording), `just_audio` (playback) |
| Device | `permission_handler`, `path_provider` |
| Calendar | `table_calendar` |
| Targets | Android, iOS, Web, Windows, macOS, Linux (Flutter scaffolding included) |

## Technical highlights

- **Two-phase recording pipeline.** Starting a recording first creates an empty `entries` row, which gives it a server-generated UUID. Audio is written to `{Documents}/svesnote/{entryId}.m4a`. On stop, the file is uploaded to `{userId}/{YYYY-MM-DD}/{entryId}.m4a` and the row is updated with the storage path and duration. The database ID drives both the local and remote file names, so the two stay consistent.
- **Repository layer.** `EntriesRepo` and `ProcessesRepo` contain all Supabase queries, so UI widgets never build queries themselves. Each repo takes an injectable `SupabaseClient`, which makes it testable.
- **Row Level Security.** The `processes` migration enables RLS with per-operation policies (`auth.uid() = user_id`), check constraints, and indexes on `user_id` and `status`. Repo queries also filter on `user_id` as a second safeguard.
- **Consistent deletes.** Deleting entries first gathers their audio paths, removes the storage objects in one batch call (and tolerates files that are already missing), then deletes the rows with a single `IN` query.
- **Auth-driven routing.** `AuthGate` is a `StreamBuilder` on `onAuthStateChange`, so logging in or out swaps the root screen without manual navigation.
- **Typed models.** `Entry` and `Process` provide `fromJson`/`toJson` plus derived getters (`isActive`, `isTimeLimited`, `isExpired`).

## Getting started

### Prerequisites

- Flutter SDK with Dart 3.10 or newer
- A Supabase project

### Backend setup

1. Create an `entries` table with the columns `id uuid`, `user_id uuid`, `created_at timestamptz`, `audio_path text`, `transcript text`, `duration_seconds int`. Enable RLS scoped to `auth.uid() = user_id`.
2. Run [`supabase/migrations/create_processes_table.sql`](supabase/migrations/create_processes_table.sql) in the SQL editor, or use `supabase db push`.
3. Create a private Storage bucket named `entries-audio`.
4. In `svesnoteapp/lib/main.dart`, set the `url` and `anonKey` passed to `Supabase.initialize` to your project's URL and publishable (anon) key.

### Run

```bash
cd svesnoteapp
flutter pub get
flutter run            # choose a device
```

Other useful commands: `flutter analyze`, `flutter test`, `flutter build apk`, and `flutter build web`.

## Project structure

```
svesnote/
├── supabase/migrations/        # SQL migration for the processes table (with RLS)
└── svesnoteapp/
    ├── lib/
    │   ├── main.dart           # Supabase init, app root
    │   ├── auth/               # AuthGate, login, 3-step registration
    │   ├── home/               # Home (record/list/calendar), processes CRUD, profile, settings
    │   ├── audio/              # just_audio playback via signed URLs
    │   ├── data/               # EntriesRepo, ProcessesRepo (Supabase access)
    │   └── models/             # Entry, Process
    └── android/ ios/ web/ windows/ macos/ linux/
```

## Author

Lazar Gošić — GitHub [@lakygosh](https://github.com/lakygosh)
