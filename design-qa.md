# Homepage and Manual Transaction Design QA

## Comparison target

- Source visual truth:
  - `assets/mockups/light_mode/homepage/homepage.png`
  - `assets/mockups/light_mode/homepage/manual.png`
  - `assets/mockups/light_mode/homepage/manual-category.png`
  - `assets/mockups/light_mode/homepage/payment-method.png`
- Rendered implementation:
  - `qa/homepage-final.png`
  - `qa/manual-final.png`
  - `qa/category-final.png`
  - `qa/payment-final.png`
- Combined comparison evidence:
  - `qa/comparison-home.png`
  - `qa/comparison-manual.png`
  - `qa/comparison-category.png`
  - `qa/comparison-payment.png`
- Device viewport: 1280 x 2856 physical pixels, approximately 426.7 x 952 logical pixels at 480 dpi (device pixel ratio 3).
- Normalization: each reference and implementation was aspect-fit into an equal 700 x 1450 comparison panel. The homepage comparison uses the populated right-hand phone from the two-state source board. System chrome remains visible in both source and implementation because it is part of the supplied screen compositions.
- States: authenticated populated dashboard, new manual transaction, category picker, and collapsed payment-method catalog.

## Findings

- No actionable P0, P1, or P2 differences remain.
- Fonts and typography: the implementation preserves the heavy dark-slate headings, muted supporting copy, bold transaction/category hierarchy, and compact labels from the references. Flutter's platform typeface is slightly wider than the mockup font; responsive wrapping is limited to supporting text and is acceptable P3 polish.
- Spacing and layout rhythm: the greeting, gradient expense summary, metric cards, spending card, history action, transaction surface, layered sheet headers, fields, and rounded group tiles follow the source order and rhythm. Shorter devices scroll the transaction list and lower picker groups instead of shrinking tap targets.
- Colors and visual tokens: white surfaces, off-white page background, purple-blue gradients, pale borders, soft shadows, teal/orange category accents, and dark slate text match the light-mode design direction and existing Broke.AI theme.
- Image quality and asset fidelity: the supplied homepage, manual, and category dog assets are rendered directly. The category/payment header mascot uses a clipped scale of the supplied asset so the character matches the source prominence without recreating it.
- Copy and content: visible fixed copy matches the references. Dynamic totals, month, user name, counts, category percentages, payment methods, and transactions intentionally come from the current session/API rather than mock data.
- Icons and controls: notification, wallet, date, receipt, category, history, navigation, close, search, accordion, and action icons use consistent Material symbols with practical tap targets. Payment previews and recent/history tiles retain the real local payment-method logo assets.
- Accessibility and responsiveness: all form fields, close controls, history action, picker rows, search, and FAB remain interactive. Sheets are scrollable, keyboard insets are respected, text truncation is bounded, and no overflow or clipped persistent control was observed.

## Comparison history

1. Initial emulator capture found a P2 payment-sheet title wrap and a P2 mascot scale mismatch in the category/payment headers. The payment header was rebuilt as a responsive stack with a single-line title, and the supplied mascot was scaled within a clipped slot.
2. Initial manual capture showed the amount as a bare `0` rather than the source's `Rp 0`. The new-entry controller now initializes to `0`, preserving the currency prefix while validation still rejects zero on submit.
3. Post-fix captures show the payment title on one line, larger source-faithful mascots, the `Rp 0` amount state, and no visual overflow. The combined comparisons contain no remaining actionable P0/P1/P2 mismatch.

## Interaction verification

- Dashboard refresh, month navigation, spending report/history navigation, bottom navigation, and FAB work with the existing providers and API data.
- Recent activity remains sourced from `/api/v1/expense/recent`, capped at five items, and displays payment logos with bold category plus description/date beneath.
- Manual date, amount, category, optional description, and payment method fields are interactive; create and edit continue to use the existing backend request mapping.
- Category selection returns one of the seven allowed values.
- Payment search filters across all nine groups in real time; groups expand/collapse and return the selected payment method.
- `flutter analyze` reports no issues, all 27 Flutter tests pass, and the Android debug APK builds successfully.

## Focused-region comparison

Separate crops were not required because each combined 1440 x 1530 comparison keeps the sheet headers, typography, mascot assets, form fields, payment logos, tiles, and primary actions legible at full-view scale.

## Follow-up polish

- P3: an exact licensed match for the mockups' display font would further narrow small optical width differences.
- P3: the design's decorative category thumbnails are not separate supplied assets, so the implementation uses the closest category icons while retaining all supplied mascot and payment-logo imagery.

final result: passed

---

# Scan and Profile Design QA

## Comparison target

- Source visual truth:
  - `assets/mockups/light_mode/scanpage/scanPage.png`
  - `assets/mockups/light_mode/profilepage/profilepage.png`
- Rendered implementation:
  - `qa/scan-final.png`
  - `qa/profile-final.png`
- Combined comparison evidence:
  - `qa/comparison-scan.png`
  - `qa/comparison-profile.png`
- Device viewport: 1280 x 2856 physical pixels, approximately 426.7 x 952 logical pixels at 480 dpi (device pixel ratio 3).
- State: idle guest scan with two trials remaining, and guest profile with registration prompt.

## Findings

- No actionable P0, P1, or P2 differences remain.
- Scan: hierarchy, trial badge, dashed receipt frame, camera/gallery actions, disabled AI state, text-entry card, gold processing action, informational callout, and selected navigation state follow the reference. The page scrolls on the verification device so lower content stays usable instead of compressing the viewfinder.
- Profile: header, guest identity card, gold registration prompt, grouped Account/Support settings, guest backup notice, and selected navigation state follow the reference. Dynamic guest identifiers remain sourced from the real session.
- Assets: the missing receipt and security-shield artwork was generated as dedicated raster assets in the same soft 3D visual language and placed in measured image slots. No placeholder boxes, text glyphs, or handcrafted vector approximations are used.
- Responsiveness: the registration banner was tightened after the first comparison so its copy and CTA remain readable in a compact horizontal composition on a 426.7-logical-pixel viewport. Long guest usernames truncate safely, lists scroll, and persistent navigation does not overflow.
- Functional states: Camera and Gallery still invoke image selection, receipt previews remain clipped inside the rounded frame, the preview-only close action is preserved, text processing and guest trial enforcement still use the existing API/provider flow, and Profile retains login/register or logout behavior according to session type.

## Comparison history

1. Initial profile capture exposed a P2 vertical expansion in the registration banner caused by narrow text and button columns. Avatar, gaps, typography, and button padding were responsively tightened.
2. The follow-up combined comparison shows the reference-faithful horizontal banner, clear copy, stable grouped cards, and no overflow.
3. The scan comparison shows the requested component order and visual states without an actionable P0/P1/P2 mismatch. The additional visible system status bar and taller emulator aspect are platform viewport differences, not component defects.

## Interaction verification

- The Home empty-state `Add Expense` button opens the same fully functional manual transaction sheet as the floating action button (`qa/add-expense-manual-final.png`).
- `flutter analyze` reports no issues, all 27 Flutter tests pass, and the Android debug APK builds successfully.

final result: passed
