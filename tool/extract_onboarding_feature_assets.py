from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/mockups/light_mode/onboarding_features"
OUTPUT.mkdir(parents=True, exist_ok=True)

crops = {
    1: (100, 1040, 370, 1310),
    2: (130, 880, 380, 1130),
    3: (90, 1210, 350, 1470),
}

for page, bounds in crops.items():
    source = Image.open(
        ROOT / f"assets/mockups/light_mode/onboardingPage{page}.png"
    ).convert("RGB")
    source.crop(bounds).save(
        OUTPUT / f"onboarding-feature-{page}.png", "PNG", optimize=True
    )
    print(page, source.size, bounds)
