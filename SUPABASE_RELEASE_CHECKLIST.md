# Safo Supabase Release Checklist

This checklist tracks the backend and auth setup that should be confirmed before TestFlight and before a public release.

## 1. Environment and Projects

- [ ] Confirm which Supabase project is used for:
  - development
  - internal testing
  - production
- [ ] Confirm `.env` values for each environment
- [ ] Confirm the release app points to the intended Supabase project

## 2. Authentication

- [ ] Confirm email auth is enabled
- [ ] Confirm magic link / OTP email templates
- [ ] Confirm reset password flow is enabled
- [ ] Confirm Google auth provider setup
- [ ] Confirm Apple auth provider setup
- [ ] Confirm redirect URLs for:
  - `safo://login-callback` on iOS
  - `safo://login-callback` on Android
  - web localhost/dev URL
  - final web production URL if used later

## 3. Auth QA

- [ ] Test sign in with email
- [ ] Test register with email
- [ ] Test reset password flow
- [ ] Test logout/login cycle
- [ ] Test Google auth end-to-end
- [ ] Test Apple auth end-to-end
- [ ] Test guest mode behavior

## 4. Database and Policies

- [ ] Review tables used by Safo:
  - households
  - household_members
  - food_items
  - shopping_list_items
  - meal_plan_entries
  - scan_sessions
  - user_preferences
- [ ] Review row-level security policies for household isolation
- [ ] Verify a user cannot read another household’s data
- [ ] Verify shared household members can read/write household-scoped data as intended
- [ ] Verify personal items migrate correctly into a newly created or joined household

## 5. Household Join Flow

- [ ] Test create household with Account A
- [ ] Copy short invite code
- [ ] Join household with Account B
- [ ] Verify both users see the same pantry
- [ ] Verify both users see the same shopping list
- [ ] Verify both users see the same meal plan
- [ ] Verify existing personal pantry items are moved into the shared household
- [ ] Verify existing personal shopping items are moved into the shared household

## 6. Data Integrity QA

- [ ] Test add/edit/delete pantry item
- [ ] Test add/edit/delete shopping item
- [ ] Test mark bought -> move to pantry
- [ ] Test meal plan create/edit/delete
- [ ] Test preference save/load
- [ ] Test scan session save/load

## 7. Stability and Monitoring

- [ ] Decide whether to enable Supabase logs/alerts review before release
- [ ] Review auth errors during first TestFlight run
- [ ] Review database errors during first TestFlight run

## 8. What Still Needs Real User Action

These items cannot be fully finished only in code and should be completed manually before store release:

- Google provider configuration
- Apple provider configuration
- final redirect URLs
- final RLS review
- real multi-account household QA
