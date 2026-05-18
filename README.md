# Safo Mobile

Safo is a shared kitchen assistant for households.

The app helps users:

- know what they already have at home
- use food before it expires
- decide what to cook faster
- manage shopping together
- keep allergies, intolerances, and diet preferences in mind

## Current Focus

This Flutter app is currently in a strong internal alpha / early TestFlight preparation phase.

The biggest remaining work is:

1. end-to-end QA
2. auth/provider production setup
3. release tooling stability
4. store/legal/support preparation

## Release Planning Docs

These working docs live in this repo:

- `STORE_LAUNCH_CHECKLIST.md`
- `APP_STORE_METADATA_DRAFT.md`
- `PRIVACY_POLICY_DRAFT.md`
- `TERMS_OF_USE_DRAFT.md`
- `SUPABASE_RELEASE_CHECKLIST.md`
- `TESTFLIGHT_QA_MATRIX.md`

## Tech Stack

- Flutter
- Supabase
- shared household data model
- pantry, shopping, recipes, meal plan, scan, and onboarding flows

## Local Development Notes

- copy `.env.example` to `.env` and fill in `SUPABASE_URL` + `SUPABASE_ANON_KEY` before testing backend-backed flows
- iOS is the main release target right now
- the project currently has a local Flutter toolchain/runtime issue affecting `flutter analyze` and `flutter test`
- app functionality and release readiness are being pushed forward in parallel with QA-driven fixes
