from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[1]
CANVAS = Image.new("RGB", (1800, 3400), "#E2E8F0")
DRAW = ImageDraw.Draw(CANVAS)

for index in range(1, 4):
    top = 80 + ((index - 1) * 1100)
    DRAW.text((70, top - 42), f"PAGE {index} - REFERENCE", fill="#0F172A")
    DRAW.text((970, top - 42), f"PAGE {index} - IMPLEMENTATION", fill="#0F172A")
    reference = Image.open(
        ROOT / f"assets/mockups/light_mode/onboardingPage{index}.png"
    ).convert("RGB")
    implementation = Image.open(
        ROOT / f"qa/implementation-onboarding-{index}.png"
    ).convert("RGB")
    reference = ImageOps.contain(reference, (800, 1020))
    implementation = ImageOps.contain(implementation, (800, 1020))
    CANVAS.paste(reference, (60 + ((800 - reference.width) // 2), top))
    CANVAS.paste(implementation, (940 + ((800 - implementation.width) // 2), top))

CANVAS.save(ROOT / "qa/onboarding-carousel-comparison.png", optimize=True)
