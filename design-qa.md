# Authentication and Onboarding Design QA

## Comparison target

- Source visual truth:
  - `assets/mockups/light_mode/loginPage.png`
  - `assets/mockups/light_mode/registerPage1.png`
  - `assets/mockups/light_mode/registerPage2.png`
  - `assets/mockups/light_mode/registerPage3.png`
- Rendered implementation:
  - `qa/implementation-login.png`
  - `qa/implementation-register-1.png`
  - `qa/implementation-register-2.png`
  - `qa/implementation-register-3.png`
- Combined comparison evidence:
  - `qa/comparison-login.png`
  - `qa/comparison-register-1.png`
  - `qa/comparison-register-2.png`
  - `qa/comparison-register-3.png`
- Device viewport: 1280 x 2856 physical pixels, 426.67 x 952 logical pixels, device pixel ratio 3.
- Normalization: implementation screenshots were cropped from y=156 through y=2784 to remove Android-owned status/navigation bars. Reference images were resized to 1280 physical pixels wide and compared beside the 1280-pixel-wide implementation crop.
- States: signed-out login, registration Step 1, registration Step 2, and registration Step 3 with realistic completed account data.

## Findings

- No actionable P0, P1, or P2 differences remain.
- Fonts and typography: the implementation preserves the mockups' heavy dark-slate display hierarchy, muted body copy, clear field labels, and purple active labels. Flutter's platform font has a slightly heavier optical appearance than the source typeface; this is acceptable P3 polish.
- Spacing and layout rhythm: the brand, progress tracker, hero, fields, information cards, and gold actions follow the source order and proportions. All primary actions fit the tested viewport. On Step 3, the secondary `Edit details` action is available after a short scroll because Android system chrome reduces the app-owned height relative to the source canvas; this is expected responsive behavior.
- Colors and visual tokens: white surfaces, slate text, purple/blue active states, pale borders, mint benefit accents, and gold primary actions are faithful to the light-mode references and existing Broke.AI palette.
- Image quality and asset fidelity: every supplied dog asset is used. Tight, lossless crops derived from those originals improve subject scale without replacing or redrawing the artwork. The brand and login feature graphics are exact source crops rather than approximated code art.
- Copy and content: headings, helper copy, field names, progress labels, benefit content, password requirements, account summary, agreement, and actions match the supplied screens. Summary values intentionally use the entered account details.
- Icons and controls: fields, password visibility controls, progress states, checkbox, back button, and forward actions use consistent Material icons and practical tap targets.
- Accessibility and responsiveness: inputs expose hints and autofill metadata; password controls have tooltips; content scrolls on shorter displays; no RenderFlex overflow, clipping, locale exception, or Flutter runtime error appeared on the tested emulator.

## Comparison history

1. First comparison found a P2 login-height issue: the sign-in action was partially below the initial viewport. The hero and login card rhythm were tightened, then the login screen was recaptured with the full action and registration link visible.
2. Second comparison found P2 registration-height issues: Step 1 and Step 3 pushed primary actions below the initial viewport. Progress, hero, benefit, and account-summary spacing were compacted. Recapture confirms all primary actions are visible.
3. Third comparison found a P2 mascot-scale mismatch. Lossless subject-aware crops were generated from the four supplied dog assets and wired into the same responsive image slots. Final recaptures show substantially closer source scale and composition.

## Interaction verification

- Onboarding automatically advances every 3 seconds and loops from Slide 3 back to Slide 1.
- Manual swiping and dot navigation remain available.
- `Sign In / Register` opens the login screen; back returns to onboarding.
- `Register` opens Step 1; valid identity details advance to Step 2; valid credentials advance to Step 3.
- Password visibility, validation, previous-step navigation, terms dialog, agreement checkbox, login request, registration request, and loading/error states are implemented.
- All 27 Flutter tests pass, `flutter analyze` reports no issues, and the Android debug APK builds successfully.
- Android logcat was checked after traversing the full flow; no Flutter runtime, locale, or layout-overflow errors were present.

## Focused-region comparison

Additional crops were not required because the four 2568-pixel-wide combined comparisons keep typography, imagery, fields, icons, and actions legible at full-view scale.

## Follow-up polish

- P3: an exact licensed match for the mockup's display font and decorative underline could narrow the remaining optical difference.

final result: passed
