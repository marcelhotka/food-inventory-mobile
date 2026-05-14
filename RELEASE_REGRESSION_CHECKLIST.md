# Safo Release Regression Checklist

Use this short checklist after any bigger product, UI, or backend-related change.

The goal is not to replace the full QA matrix. It is to quickly catch regressions in the flows that matter most before we hand a build to testers.

## 1. Auth and First Run

- [ ] Splash shows correctly
- [ ] Onboarding summary -> Welcome -> Onboarding order is correct
- [ ] Swipe navigation works forward/backward where expected
- [ ] Sign in screen renders correctly
- [ ] Register screen renders correctly
- [ ] Forgot password flow opens and returns cleanly
- [ ] Guest mode still reaches setup correctly
- [ ] Logout returns to the correct first-run flow

## 2. Household Create / Join / Share

- [ ] Create household works end-to-end
- [ ] Join household works with short invite code
- [ ] Join household works with copied code containing spaces or separators
- [ ] Existing personal pantry items move into the joined household correctly
- [ ] Existing personal shopping items move into the joined household correctly
- [ ] Invite code copy action works
- [ ] Household member list renders readable names

## 3. Kitchen Preferences and Safety Inputs

- [ ] Favorite meals selection saves correctly
- [ ] Favorite foods selection saves correctly
- [ ] Allergies selection saves correctly
- [ ] Intolerances selection saves correctly
- [ ] Diet style multi-select saves only valid options
- [ ] Language selection saves correctly
- [ ] Cooking frequency selection saves correctly

## 4. Pantry Safety and Expiration

- [ ] Add pantry item works
- [ ] Edit pantry item works
- [ ] Opened item flow updates guidance correctly
- [ ] Expiration display still makes sense
- [ ] Low stock state still makes sense
- [ ] Allergy/intolerance warning display is sensible
- [ ] Eggs do not show false lactose warnings
- [ ] Lactose-free products do not show false lactose warnings
- [ ] Gluten-free products do not show false gluten warnings

## 5. Shopping to Pantry Flow

- [ ] Add shopping item works
- [ ] Edit shopping item works
- [ ] Mark bought works
- [ ] Bought item moves into pantry correctly
- [ ] Similar items merge correctly
- [ ] Quantity aggregation still works
- [ ] Suggested safer variants still make sense

## 6. Recipes and Scaling

- [ ] Recipe list renders
- [ ] Recipe detail opens
- [ ] Safe-for-you filtering works
- [ ] 15/30/45 minute modes work
- [ ] Servings recalculation updates ingredient amounts
- [ ] Nutrition insight still renders correctly
- [ ] Add missing ingredients to shopping list works

## 7. Quick Commands

- [ ] Command preview opens before execution
- [ ] `pridaj 2 jogurty a mlieko` parses correctly
- [ ] `minuli sa vajcia` parses correctly
- [ ] `otvoril som syr` parses correctly
- [ ] Special variants stay distinct from standard items
- [ ] Classical bread does not merge into gluten-free bread
- [ ] Lactose-free products stay lactose-free after execution

## 8. Meal Plan and Dashboard

- [ ] Add meal plan entry works
- [ ] Assign cook works
- [ ] Linked recipe behavior works
- [ ] Dashboard welcome state still feels correct
- [ ] What-to-do-today suggestions still make sense
- [ ] Quick recipe recommendations still open correctly

## 9. Scan and Utility Flows

- [ ] Barcode lookup works
- [ ] Fridge scan flow works
- [ ] Scan history renders correctly
- [ ] Tester sample data tools still work

## 10. System States

- [ ] Branded loading state looks correct
- [ ] Branded empty state looks correct
- [ ] Branded error state looks correct
- [ ] Offline/no-connection state looks correct
- [ ] Dialogs still use the Safo style
- [ ] Snackbars/toasts still feel consistent
