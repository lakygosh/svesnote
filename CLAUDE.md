# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Svesnote is a Flutter mobile/web application for voice note recording and journaling. Users can authenticate, record audio notes, upload them to cloud storage, and play them back.

**Tech Stack:** Flutter (Dart), Supabase (auth + PostgreSQL + storage), flutter_sound (recording), just_audio (playback)

## Commands

All commands should be run from the `svesnoteapp/` directory:

```bash
# Install dependencies
flutter pub get

# Run the app (will prompt for device selection)
flutter run

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Analyze code for lint issues
flutter analyze

# Format code
dart format lib/

# Build for specific platforms
flutter build apk      # Android
flutter build ios      # iOS
flutter build web      # Web
flutter build windows  # Windows
```

## Architecture

```
svesnoteapp/lib/
├── main.dart                    # App entry, Supabase initialization
├── auth/
│   ├── auth_gate.dart           # StreamBuilder routing based on auth state
│   ├── login_screen.dart        # Email/password login
│   └── register_screen.dart     # 3-step registration (email → password → username)
├── home/
│   └── home_screen.dart         # Main screen: recording, playback, entry list
├── audio/
│   └── audio_playback_service.dart  # just_audio wrapper for playback
├── data/
│   └── entries_repo.dart        # Supabase database operations
└── models/
    └── entry.dart               # Entry data model with fromJson/toJson
```

### Key Patterns

- **Auth flow:** `AuthGate` uses StreamBuilder on `onAuthStateChange` to route between LoginScreen and HomeScreen
- **State management:** StatefulWidget with setState() - no state management library
- **Data access:** Single `EntriesRepo` class handles all Supabase database calls
- **Audio recording:** Saves to local storage first (`{Documents}/svesnote/{entryId}.m4a`), then uploads to Supabase Storage (`{userId}/{YYYY-MM-DD}/{entryId}.m4a`)

### Database Schema

**Table: entries**
- `id` (UUID), `user_id` (UUID), `created_at` (timestamp)
- `audio_path` (text, nullable), `transcript` (text, nullable), `duration_seconds` (int, nullable)

**Storage bucket:** `entries-audio`

## Configuration

Supabase credentials are in `main.dart` (publishable anon key). SDK version: `^3.10.4`
