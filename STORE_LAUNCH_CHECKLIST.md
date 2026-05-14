# Safo Store Launch Checklist

This checklist tracks what still needs to be finished before Safo can move from internal testing to a real store release.

## 1. Product Readiness

- [ ] Run a full QA pass on iPhone for:
  - onboarding
  - sign in / register / reset password
  - create household / join household
  - pantry
  - shopping list
  - recipes
  - meal plan
  - scan flows
  - notifications
  - household sharing
- [ ] Run the same QA pass in Chrome/web
- [ ] Verify Slovak and English copy on all core screens
- [ ] Verify that all error, empty, loading, success, and delete states feel production-ready
- [ ] Verify that swipe/back/forward flow behaves consistently in onboarding
- [ ] Review dashboard density and simplify any section that still feels too busy during real usage

## 2. Technical Readiness

- [ ] Fix the local Flutter toolchain/runtime issue so `flutter analyze` works reliably
- [ ] Fix the local Flutter toolchain/runtime issue so `flutter test` works reliably
- [ ] Run `flutter analyze` clean on the whole app
- [ ] Run `flutter test` clean on the whole app
- [ ] Add a lightweight release regression checklist for:
  - auth
  - household join/share
  - allergy/intolerance warnings
  - shopping to pantry flow
  - recipe scaling
  - quick command parsing

## 3. Auth and Supabase

- [ ] Confirm Supabase production project/environment values
- [ ] Confirm email auth redirect URLs for:
  - iOS callback
  - Android callback
  - web callback
- [ ] Enable and test Google auth in Supabase
- [ ] Enable and test Apple auth in Supabase
- [ ] Test reset password flow end-to-end
- [ ] Review RLS/policies for:
  - households
  - household members
  - food items
  - shopping list items
  - meal plan entries
  - scan sessions
- [ ] Verify household invite / join flow with 2 real accounts
- [ ] Verify migration of personal pantry/shopping items into a shared household

## 4. Permissions and Device Behavior

- [ ] Verify camera permission copy and scan flow on iPhone
- [ ] Verify photo library permission copy and fallback flow
- [ ] Verify notification permission flow if push/local notifications are enabled
- [ ] Verify app behavior when device is offline
- [ ] Verify app behavior when Supabase is unavailable
- [ ] Verify app behavior after logout/login and cold start

## 5. Analytics and Stability

- [ ] Add crash reporting
- [ ] Add lightweight product analytics for key flows
- [ ] Define which events matter before launch:
  - account created
  - household created
  - household joined
  - first pantry item added
  - first shopping item added
  - first recipe opened
  - first scan completed
- [ ] Verify no sensitive/private data is sent in analytics payloads

## 6. Legal and Support

- [ ] Finalize Privacy Policy
- [ ] Finalize Terms of Use or basic usage terms
- [ ] Decide support email
- [ ] Decide support URL / landing page
- [ ] Decide privacy policy hosting URL

## 7. Store Assets

- [ ] Final app icon set confirmed
- [ ] Splash/launch visuals confirmed
- [ ] App Store screenshots for iPhone sizes
- [ ] Optional preview video if desired
- [ ] Marketing one-liner confirmed

## 8. App Store / TestFlight Metadata

- [ ] Final app name
- [ ] Subtitle
- [ ] Keywords
- [ ] Short and long description
- [ ] Category selection
- [ ] Age rating questionnaire
- [ ] Privacy questionnaire in App Store Connect
- [ ] Support URL
- [ ] Privacy Policy URL

## 9. Release Build Readiness

- [ ] Confirm bundle identifier
- [ ] Confirm signing / certificates / provisioning
- [ ] Confirm release version number strategy
- [ ] Archive the iOS build successfully in Xcode
- [ ] Upload first build to TestFlight
- [ ] Test the TestFlight build on at least 2 devices/accounts

## 10. Launch Sequence

### Internal Alpha

- [ ] Developer testing complete
- [ ] Known blocker list reviewed
- [ ] Internal build shared

### TestFlight / Closed Beta

- [ ] Invite first testers
- [ ] Gather onboarding pain points
- [ ] Gather bug reports
- [ ] Gather first “what is confusing?” feedback

### Public Store Release

- [ ] Freeze release candidate
- [ ] Final metadata review
- [ ] Final legal/support links review
- [ ] Submit for review

## Current Best Guess

Safo looks close to a strong internal alpha / early TestFlight build.

The biggest remaining work before store release is not visual polish anymore. It is:

1. end-to-end QA
2. auth/provider production setup
3. release tooling stability
4. legal + store metadata

## Companion Docs In This Repo

- `APP_STORE_METADATA_DRAFT.md`
- `PRIVACY_POLICY_DRAFT.md`
- `TERMS_OF_USE_DRAFT.md`
- `SUPABASE_RELEASE_CHECKLIST.md`
- `TESTFLIGHT_QA_MATRIX.md`
- `APP_STORE_SCREENSHOT_PLAN.md`
- `TESTFLIGHT_FEEDBACK_TEMPLATE.md`
