# Safo TestFlight QA Matrix

Use this as the practical test pass before a real TestFlight round.

## A. First-Run Flow

- [ ] Splash screen appears correctly
- [ ] Onboarding summary appears in correct order
- [ ] Welcome screen image and CTA layout look correct
- [ ] Swipe navigation works forward/backward where intended
- [ ] Sign in screen layout looks correct
- [ ] Register screen layout looks correct
- [ ] Forgot password screen works visually and functionally
- [ ] Link sent / success state looks correct

## B. Household Setup

- [ ] Create household flow works
- [ ] Join household flow works
- [ ] Invite code accepts copied/pasted values cleanly
- [ ] Join code works with short code
- [ ] Join code does not behave badly with spaces or separators
- [ ] Back navigation in household flow makes sense

## C. Kitchen Setup

- [ ] Favorite meals selection works
- [ ] Favorite foods selection works
- [ ] Allergies selection works
- [ ] Intolerances selection works
- [ ] Diet style multi-select works
- [ ] Language selection works
- [ ] Cooking frequency selection works
- [ ] Household size validation works
- [ ] Continue sends user to dashboard correctly

## D. Dashboard

- [ ] Welcome state after onboarding feels correct
- [ ] Main cards render without overflow
- [ ] Quick recipe suggestions open correctly
- [ ] Safe-for-you behavior still works
- [ ] Alerts / “what to do today” content makes sense

## E. Pantry

- [ ] Add pantry item
- [ ] Edit pantry item
- [ ] Delete pantry item
- [ ] Opened item flow works
- [ ] Expiration display works
- [ ] Low stock display works
- [ ] Allergy/intolerance warning display makes sense
- [ ] Eggs do not show false lactose warnings

## F. Shopping List

- [ ] Add item
- [ ] Edit item
- [ ] Delete item
- [ ] Assign item
- [ ] Mark bought
- [ ] Move bought item to pantry
- [ ] Merge similar items works correctly
- [ ] Safety suggestion text makes sense

## G. Recipes

- [ ] Recipe list renders correctly
- [ ] Recipe detail opens correctly
- [ ] Safe-for-you filtering works
- [ ] 15/30/45 minute mode works
- [ ] Servings recalculation works
- [ ] Nutrition insight renders correctly
- [ ] Add missing ingredients to shopping list works

## H. Meal Plan

- [ ] Add meal plan entry
- [ ] Edit meal plan entry
- [ ] Delete meal plan entry
- [ ] Assign cook works
- [ ] Linked recipe behavior works

## I. Household

- [ ] Member list looks correct
- [ ] Invite code section looks correct
- [ ] Household feed looks correct
- [ ] “Na teba čaká” section looks correct

## J. Scan / Utilities

- [ ] Barcode lookup screen works
- [ ] Fridge scan screen works
- [ ] Scan history looks correct
- [ ] Quick command preview works
- [ ] Quick command execution works
- [ ] Tester tools still work for internal testing

## K. System States

- [ ] Loading states look branded
- [ ] Empty states look branded
- [ ] Error states look branded
- [ ] Offline/no-connection state looks correct
- [ ] Dialogs look consistent
- [ ] Snackbars/toasts feel consistent

## L. Account and Session

- [ ] Logout works from dashboard
- [ ] Logout works from onboarding/setup
- [ ] Fresh start from first screen still works
- [ ] Cold start returns user to the right screen

## M. Launch Decision

- [ ] Good enough for internal alpha
- [ ] Good enough for TestFlight
- [ ] Blocked for public store release

## Notes

Record bugs during this pass with:

- screen name
- exact action
- expected result
- actual result
- screenshot if visual
