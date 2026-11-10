# Nibbl 🍡

**Snap, say or type what you eat. Nibbl handles the numbers.**

Nibbl is an offline-first AI calorie and macro tracker built with Flutter (Android + iOS). It works out of the box with a realistic **demo AI**. Point it at any OpenAI-compatible endpoint to use a real vision model.

## Quick start

```bash
flutter pub get
flutter run                 # demo AI, no key needed
flutter test                # unit tests (calculator + AI parsing)
flutter build apk --release # build/app/outputs/flutter-apk/app-release.apk
```

Requirements: Flutter 3.44+ / Dart 3.12+, Android SDK 36 (compileSdk 36, minSdk 24), iOS 13+.

## Configuring the AI

Settings come from `.env` (bundled as an asset). Values passed with `--dart-define` take priority.

| Key | Meaning | Default |
| --- | --- | --- |
| `AI_PROVIDER` | `anthropic` (native Claude Messages API) or `openai` (any OpenAI-compatible API) | auto-detected (`sk-ant-` keys → `anthropic`) |
| `USE_MOCK_AI` | `true` uses the offline demo AI | `true` when no base URL is set |
| `AI_BASE_URL` | OpenAI-compatible base URL, e.g. `https://my-proxy.workers.dev` | empty |
| `AI_API_KEY` | Sent as `Authorization: Bearer …` if set | empty |
| `AI_MODEL` | Text model (parsing and coach) | `claude-opus-5-5` (Claude) / `gpt-4o-mini` (OpenAI) |
| `AI_VISION_MODEL` | Vision model (photos) | same as `AI_MODEL` |

```bash
flutter run --dart-define=USE_MOCK_AI=false --dart-define=AI_BASE_URL=https://your-proxy.workers.dev
```

### ⚠️ Keep provider keys off the device

Anything inside an APK or IPA can be extracted, including `.env` and `--dart-define` values. In production:

1. Deploy [`proxy/worker.js`](proxy/worker.js) (a Cloudflare Worker) with your provider key stored as a secret.
2. Set `AI_BASE_URL` to the worker URL. Leave `AI_API_KEY` empty, or set it to a low-value shared `APP_TOKEN`.
3. For a public launch, add per-user authentication and rate limiting to the proxy.

`.env` is git-ignored. Copy `.env.example` to `.env` after cloning, because the build expects the asset to exist.

## Architecture

```
lib/
  core/          config, theme (design tokens), router, services (haptics, notifications), utils
  domain/        entities, repository interfaces, AiService interface, NutritionCalculator
  data/          Hive repositories, OpenAI-compatible + mock AI, Open Food Facts API, backups, seed food DB
  presentation/  Riverpod providers, shared widgets, screens
```

* **State:** Riverpod 3 `Notifier`s. Derived data such as day summaries, streaks and progress stats comes from plain `Provider`s.
* **Storage:** Hive boxes of JSON strings. No code generation, and backups are a simple dump/restore.
* **Navigation:** go_router with a `StatefulShellRoute` for the tabs, plus an onboarding redirect.
* **Targets:** Mifflin-St Jeor BMR × activity multiplier, adjusted by ±(pace × 7700 / 7) kcal per day, with a 1200/1500 kcal floor.

Nutrition values are estimates and are not medical advice.

## Friends & posts (Supabase)

Usernames, friend requests and the friends feed run on [Supabase](https://supabase.com) (free tier is enough).
Without it the Friends screens run in an offline demo with sample friends.

1. Create a project at supabase.com.
2. **SQL Editor → New query**, paste all of [`supabase/schema.sql`](supabase/schema.sql) and click **Run**.
   It creates the tables, privacy rules (only you and accepted friends see your posts and photos),
   the `post-photos` storage bucket and the feed/friend functions.
3. **Authentication → Sign In / Providers → Allow anonymous sign-ins: ON.**
   Accounts are created silently the first time someone picks a username.
4. **Project Settings → API**: copy the Project URL and the publishable (anon) key into `.env`:

   ```
   SUPABASE_URL=https://xxxx.supabase.co
   SUPABASE_KEY=sb_publishable_...
   ```

5. Rebuild the app.

The publishable key is meant to ship in apps; the database rules are what protect the data.
Accounts are anonymous and tied to the device, so a reinstall loses the username. Add email or
Google sign-in later to let people recover their account.
