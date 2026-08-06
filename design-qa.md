# App Icon, Boot, and Onboarding Design QA

## Evidence

- Source visual truth:
  - `assets/app-icon/icon-2.png` (1254 x 1254 px)
  - `assets/mockups/light_mode/onboardingPage1.png` (941 x 1672 px)
  - `assets/mockups/light_mode/onboardingPage2.png` (941 x 1672 px)
  - `assets/mockups/light_mode/onboardingPage3.png` (853 x 1844 px)
- Rendered implementation:
  - `qa/implementation-native-splash.png` (1280 x 2856 px)
  - `qa/implementation-flutter-boot.png` (1280 x 2856 px)
  - `qa/implementation-onboarding-1.png` (1280 x 2856 px)
  - `qa/implementation-onboarding-2.png` (1280 x 2856 px)
  - `qa/implementation-onboarding-3.png` (1280 x 2856 px)
- Full-view comparison evidence: `qa/onboarding-carousel-comparison.png`.
- Device viewport: Android 17 emulator, 1280 x 2856 physical pixels, 426.67 x 952 logical pixels, device pixel ratio 3.0.
- State: clean app data, signed out, onboarding pages 1 through 3.
- Normalization: each source and implementation pair was proportionally fitted into an 800 x 1020 comparison panel. The references include different decorative device frames, while the implementation capture is the unframed Android app viewport; system chrome and frame-only differences were not scored as app-content defects.
- Focused comparison: a separate crop was not needed because the high-resolution three-row comparison keeps the headings, feature illustrations, dots, buttons, borders, and copy readable. The native and Flutter boot states were inspected independently at full resolution.

## Findings

- No actionable P0, P1, or P2 differences remain.
- Fonts and typography: the implementation preserves the references' heavy display hierarchy, blue highlighted final line, compact body copy, and bold CTA labels without clipping. The platform font fallback has a small optical difference from the rendered mockup font but keeps the intended wrapping and hierarchy.
- Spacing and layout rhythm: all three pages retain the same hero, feature card, three-dot indicator, primary CTA, and secondary CTA order. The layout adapts the shorter framed references to the emulator's taller viewport without hiding controls or requiring a scroll to reach the main actions.
- Colors and visual tokens: the off-white background, dark slate text, electric blue highlight, soft lavender borders, gold active dot, gold gradient CTA, and blue outlined secondary action follow the selected references.
- Image quality and asset fidelity: all three supplied dog assets are rendered at high quality. The rocket, analytics clipboard, and receipt illustrations are extracted from the supplied reference art and used directly rather than approximated with generic icons. The supplied app icon is used by the native splash, Flutter boot page, and platform launcher assets.
- Copy and content: the three headings, explanatory text, Guest Mode, Smarter Insights, Smart Tracking, Try Now, and Sign In / Register content match the reference intent and remain readable.
- Accessibility and behavior: pages expose semantic page numbers and heading labels; dots and cards are tappable; swipe navigation works; and both CTAs retain practical mobile tap targets.

## Comparison History

1. The first device pass found a P2 overlap between the coded headings/body copy and text or objects embedded in the dog illustrations. The hero artwork was moved right, heading width was corrected, and a white-to-transparent readability mask was added behind the text.
2. The first pass also found a P2 asset-fidelity mismatch because the feature cards used generic Material icons. The rocket, insights clipboard, and receipt illustrations were extracted from the supplied mockups and wired into the cards as real raster assets.
3. The post-fix captures for all three states were combined and inspected in `qa/onboarding-carousel-comparison.png`; headings, feature art, controls, and persistent actions are now readable and aligned with the references.

## Interaction and Runtime Checks

- Native Android launch displays the supplied dog icon instead of the Flutter icon.
- Flutter displays a branded Broke.AI boot page for a minimum of 900 milliseconds before resolving the session route.
- Horizontal swipes move through all three onboarding pages and update the active dot.
- Sign In / Register opens the existing authentication page and can return to onboarding.
- Try Now was exercised against the live guest endpoint and opened the Guest dashboard.
- Android runtime logs were checked after launch, carousel navigation, and guest entry; no Flutter exceptions, unhandled exceptions, or locale-formatting errors were present.

## Follow-up Polish

- P3: bundle the exact reference font if pixel-identical typography across Android and iOS becomes a release requirement.

final result: passed
