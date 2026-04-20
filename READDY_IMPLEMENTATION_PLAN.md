# Safo Readdy Implementation Plan

## Goal

Use the Readdy export as the visual source of truth for the first
release-looking version of Safo, while keeping the existing Flutter logic,
Supabase flows, localization, and product behavior intact.

This plan is intentionally implementation-first:
- reuse the visual system from Readdy,
- preserve current Flutter architecture,
- migrate screen by screen,
- avoid a risky "big bang" rewrite.

## What We Received

Readdy export file:
- `/Users/marcelhotka/Downloads/project-8591687.zip`

Format:
- React
- TypeScript
- Vite
- Tailwind CSS

This is not directly reusable in Flutter, but it is very useful as:
- a visual blueprint,
- a component inventory,
- a screen/state map,
- a branding and spacing reference.

## Screens Found In Readdy

Core product screens:
- Dashboard
- Pantry
- Shopping List
- Recipes
- Recipe Detail
- Meal Plan
- Add Food
- Scan
- Household
- Settings

State and support screens:
- Auth
- Onboarding
- Empty states
- Loading states
- Error states
- Offline state
- Success and delete modals

## Visual Direction Observed

The Readdy export already defines a clear visual language for Safo:
- warm neutral background
- rounded cards and chips
- soft borders instead of heavy dividers
- clean app shell with bottom navigation
- compact but friendly dashboard cards
- gentle color coding for urgency and categories

Primary style cues identified from the export:
- background: `#FAF8F5`
- main text: `#1E2D4E`
- muted text: `#6B7268`
- border: `#E8E6E1`
- success/green: `#4CAF72`
- warning/yellow: `#D4A017`
- alert/salmon: `#E8956F`
- accent/indigo used in recipe/dashboard highlights

## What We Should Reuse In Flutter

### 1. Design Tokens

First convert the visual system into Flutter tokens:
- app colors
- text styles
- spacing scale
- radii
- border treatments
- card backgrounds
- chip styles

These should live in shared theme files instead of being hardcoded inside each
screen.

### 2. Shared App Shell

The Readdy `AppShell` gives us a strong target for:
- bottom navigation
- screen padding
- page header rhythm
- floating action placement
- consistent scroll and card structure

This should be implemented before redesigning individual screens.

### 3. Reusable Components

Before migrating full screens, build Flutter equivalents for:
- summary cards
- action chips
- search bars
- rounded section cards
- list rows
- availability pills
- expiry badges
- empty states
- error states
- dashboard quick action buttons

## What Must Stay From Current Flutter App

These areas should be preserved and only re-skinned:
- routing and navigation behavior
- Supabase data flows
- pantry logic
- shopping list logic
- recipe matching and safety logic
- household collaboration logic
- quick command logic
- localization (`en` / `sk`)
- existing async and feedback patterns

Important rule:
- migrate presentation first,
- do not rewrite working business logic unless redesign work exposes a real
  structural issue.

## Best First Wave

Start with the 3 most valuable screens:

1. Dashboard
2. Pantry
3. Recipes

Why these first:
- they define the daily feel of the app,
- they are used most often,
- they shape the first impression for testing,
- they already exist both in Flutter and Readdy,
- they benefit most from stronger visual polish.

## Recommended Rollout

### Phase 1: Theme Foundation

Build:
- Safo color palette
- text theme
- spacing constants
- card and chip system
- shared search field
- shared section header
- shared empty and state containers

Output:
- app starts to look like Safo globally, even before every screen is migrated.

### Phase 2: App Shell

Implement:
- updated bottom navigation
- unified screen scaffold
- consistent headers
- spacing and safe area behavior

Target files likely affected:
- app shell / home shell
- navigation widgets
- shared scaffold widgets

### Phase 3: Dashboard

Map Readdy dashboard ideas into existing Safo dashboard logic:
- top greeting and household identity
- summary metrics
- quick actions
- attention banner
- recent updates

Keep current Safo-only logic:
- safe recipes
- quick cook recommendations
- onboarding checklist
- "Co dnes spraviť"
- household-aware insights

Implementation note:
- this should not become a 1:1 clone if current Safo logic is richer.
- use Readdy layout language, but preserve product intelligence already built.

### Phase 4: Pantry

Use Readdy pantry as the visual target for:
- search
- category chips
- grouped list cards
- expiry badges
- low stock markers

Keep current Safo pantry logic:
- open item tracking
- expiry workflows
- fridge scan
- barcode lookup
- duplicate merge behavior
- allergy/intolerance warnings where relevant

### Phase 5: Recipes

Use Readdy recipes as the visual target for:
- search
- filter chips
- recipe cards
- recipe detail rhythm
- availability indicators

Keep current Safo recipe logic:
- safe for me
- quick cook filters
- serving recalculation
- shopping list integration
- nutrition insight
- direct opening from dashboard sections

## Secondary Wave

After the first 3 screens:
- Shopping List
- Meal Plan
- Household
- Settings / Preferences
- Scan screens

## System States To Port From Readdy

Readdy includes strong system-state coverage. We should explicitly port:
- empty states
- loading states
- generic error states
- offline state
- success modal language
- delete confirmation style

This fits well with the recent Safo work on:
- richer `AppErrorState`
- richer snackbars via `app_feedback.dart`

## Technical Strategy

### Do Not Import React Code Directly

Use the React code as reference for:
- structure,
- spacing,
- naming,
- priority of information.

Then rebuild in Flutter using:
- existing feature modules,
- shared widgets,
- app theme,
- current state management.

### Keep Risk Low

For each screen:
1. identify current Flutter logic,
2. identify Readdy visual sections,
3. create shared components if repeated,
4. swap layout incrementally,
5. analyze and test before moving on.

### Preserve Localization

Any visible text coming from Readdy must be adapted to:
- current Safo localization helpers,
- Slovak primary usage,
- English fallback support.

## Concrete Next Implementation Step

The best next coding step is:

1. create shared Safo theme tokens,
2. refactor the bottom shell to match Readdy direction,
3. redesign the dashboard with current logic preserved.

That gives the biggest visual upgrade with the lowest functional risk.

## Definition Of Done For First Release-Looking Milestone

Safo should feel ready for external testers when:
- the app shell feels consistent,
- Dashboard, Pantry, and Recipes match the new visual language,
- empty/loading/error states match the brand,
- English and Slovak still work,
- current product logic is unchanged or improved,
- the app looks intentional on phone-size screens.

## Nice-To-Have Assets To Request Later

If available from Readdy or elsewhere, these would help:
- logo files for light/dark or monochrome use
- app icon exports
- splash artwork
- any custom illustrations
- exact icon set reference
- screen screenshots for visual QA after Flutter implementation
