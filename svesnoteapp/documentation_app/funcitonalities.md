# Svesnote Application Features

## Overview
- Flutter application with Supabase email/password authentication.
- `main.dart` calls `Supabase.initialize` (Supabase URL + anon key) and launches `MyApp` with `AuthGate` as the initial widget.

## Navigation and Session Flow
- `AuthGate` uses `onAuthStateChange` stream and current session state; if session exists -> `HomeScreen`, otherwise -> `LoginScreen`.
- Supabase persists session locally; restarting the application automatically goes through the same gate.

## LoginScreen (lib/auth/login_screen.dart)
- Two `TextField` fields for email and password; stateful screen.
- Buttons: `Login` calls `signInWithPassword`; below the form is a "Don't have an account? Sign up" link that navigates to registration.
- `_loading` blocks interactions and shows `...`; errors (`AuthException` or fallback message) are displayed in red below the forms.
- After successful login or signup (if email verification is disabled), `AuthGate` redirects to `HomeScreen`.

## RegisterScreen (lib/auth/register_screen.dart)
- Step-by-step registration: email -> password + confirmation -> username.
- Validations: email format, password minimum 6 characters, passwords match, username not empty.
- `signUp` writes `username` to `user_metadata`; if there's no session (email verification enabled), it attempts `signInWithPassword`.
- After successful registration and login, navigates to `HomeScreen`.

## HomeScreen (lib/home/home_screen.dart)
- Reads `Supabase.instance.client.auth.currentUser` and displays email + username (from `user_metadata`).
- "New entry" button creates an empty entry in the `entries` table and refreshes the list.
- Entry list is loaded from Supabase (`entries` for current user, sorted by `created_at` descending).
- Each entry displays date/time and transcript preview (first 40 characters); if none, displays "No transcript yet".
- States: loading spinner, errors displayed as text in the list, `RefreshIndicator` enables pull-to-refresh.
- Logout icon in `AppBar` calls `signOut` and returns user to login screen.

## Entries (lib/models/entry.dart, lib/data/entries_repo.dart)
- `Entry` model: `id`, `userId`, `createdAt`, `audioPath`, `transcript`, `durationSeconds` + `fromJson/toJson`.
- `EntriesRepo` uses `Supabase.instance.client` and `currentUser.id` for `fetchEntries()` and `createEmptyEntry()`.

## Other
- `main.dart` contains a template `MyHomePage` counter screen that is currently not used in navigation.
- Minimal entry list support has been added (without audio recording and transcription).

## Quick User Flow
1. App start -> Supabase init -> entry to `AuthGate`.
2. Session exists => `HomeScreen` opens.
3. No session => `LoginScreen` is displayed.
4. Click on `Login` or `Register` calls Supabase auth; any errors are displayed.
5. Click logout on Home returns user to login.
