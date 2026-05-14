# Safo Supabase Auth Provider Setup

Use this when preparing Safo for TestFlight or a public release.

## Goal

Enable and verify:

- email sign in / register
- reset password
- Google sign in
- Apple sign in

## 1. Redirect Targets Already Used In App

Current mobile callback scheme in the app:

- `safo://login-callback`

This is already wired in:

- iOS `Info.plist`
- Android `AndroidManifest.xml`

## 2. Supabase Auth URL Setup

In Supabase Auth settings, confirm:

- Site URL
- Redirect URLs

Add at minimum:

- `safo://login-callback`

For web/dev flows, also add the local URLs you actually use during testing, for example:

- `http://127.0.0.1:7357`
- `http://127.0.0.1:7358`
- `http://127.0.0.1:7360`

Only keep the final production URLs that you truly need before public launch.

## 3. Email Auth

In Supabase:

- enable Email provider
- confirm sign-in and sign-up behavior
- confirm password reset is enabled
- review email templates for:
  - magic link / OTP
  - password reset

## 4. Google Auth

In Google Cloud:

- create OAuth credentials
- configure authorized redirect URI from Supabase

In Supabase:

- enable Google provider
- paste client ID and client secret

Then test in Safo:

- tap Google sign in
- complete consent flow
- confirm user lands back in app

## 5. Apple Auth

In Apple Developer:

- configure Sign in with Apple
- create the required service/app identifiers if needed
- configure return URL values required by Supabase

In Supabase:

- enable Apple provider
- configure Apple credentials

Then test in Safo:

- tap Apple sign in
- complete Apple login
- confirm user lands back in app

## 6. Reset Password

Test this end-to-end:

1. Open `Forgot password`
2. Send reset email
3. Open email on a real device
4. Confirm redirect behavior
5. Confirm the user can complete reset successfully

## 7. QA Notes

Verify these flows with at least 2 real accounts:

- email register
- email sign in
- Google sign in
- Apple sign in
- reset password
- logout and return

## 8. Common Failure Points

- missing redirect URL
- wrong callback scheme
- provider enabled in UI but missing real provider credentials
- Apple setup incomplete in Apple Developer
- provider works on web but not on mobile callback

## 9. Suggested Release Order

1. email auth
2. reset password
3. Google auth
4. Apple auth
5. final multi-device QA
