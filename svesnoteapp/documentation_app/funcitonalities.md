# Funkcionalnosti aplikacije Svesnote

## Pregled
- Flutter aplikacija sa Supabase email/password autentikacijom.
- `main.dart` poziva `Supabase.initialize` (Supabase URL + anon ključ) i pokreće `MyApp` sa `AuthGate` kao početnim widgetom.

## Navigacija i tok sesije
- `AuthGate` koristi `onAuthStateChange` strim i trenutno stanje sesije; ako postoji session -> `HomeScreen`, ako ne -> `LoginScreen`.
- Supabase pamti session lokalno; ponovni start aplikacije automatski prolazi kroz isti gate.

## LoginScreen (lib/auth/login_screen.dart)
- Dva `TextField` polja za email i lozinku; stateful ekran.
- Dugmad: `Login` poziva `signInWithPassword`; ispod forme je link "Don't have an account? Sign up" koji vodi na registraciju.
- `_loading` blokira interakcije i prikazuje `...`; greške (`AuthException` ili fallback poruka) se prikazuju crveno ispod formi.
- Nakon uspešnog login-a ili signup-a (ako su email potvrde isključene), `AuthGate` preusmerava na `HomeScreen`.

## RegisterScreen (lib/auth/register_screen.dart)
- Step-by-step registracija: email -> lozinka + potvrda -> username.
- Validacije: email format, lozinka min 6 karaktera, lozinke se poklapaju, username nije prazan.
- `signUp` upisuje `username` u `user_metadata`; ako nema session-a (email potvrda uključena), pokušava `signInWithPassword`.
- Nakon uspešne registracije i login-a navigira na `HomeScreen`.

## HomeScreen (lib/home/home_screen.dart)
- Čita `Supabase.instance.client.auth.currentUser` i prikazuje email + username (iz `user_metadata`).
- Dugme "New entry" kreira prazan unos u tabeli `entries` i osvežava listu.
- Lista unosa se učitava iz Supabase (`entries` za trenutnog korisnika, sortirano po `created_at` opadajuće).
- Svaki unos prikazuje datum/vreme i preview transcript-a (prvih 40 karaktera); ako nema, prikazuje "No transcript yet".
- Stanja: loading spinner, greške kao tekst u listi, `RefreshIndicator` omogućava pull-to-refresh.
- Logout ikonica u `AppBar` poziva `signOut` i vraća korisnika na login ekran.

## Entries (lib/models/entry.dart, lib/data/entries_repo.dart)
- `Entry` model: `id`, `userId`, `createdAt`, `audioPath`, `transcript`, `durationSeconds` + `fromJson/toJson`.
- `EntriesRepo` koristi `Supabase.instance.client` i `currentUser.id` za `fetchEntries()` i `createEmptyEntry()`.


## Ostalo
- `main.dart` sadrži šablonski `MyHomePage` counter ekran koji se trenutno ne koristi u navigaciji.
- Dodata je minimalna podrška za listu unosa (bez audio snimanja i transkripcije).

## Brzi korisnički flow
1. Start aplikacije -> Supabase init -> ulazak u `AuthGate`.
2. Postoji session => otvara se `HomeScreen`.
3. Nema sesije => prikazuje se `LoginScreen`.
4. Klik na `Login` ili `Register` poziva Supabase auth; eventualne greške se prikazuju.
5. Klik na logout na Home vraća korisnika na login.
