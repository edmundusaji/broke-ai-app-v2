from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
MOCKUPS = ROOT / "assets" / "mockups" / "light_mode"
QA = ROOT / "qa"

PAIRS = {
    "login": (MOCKUPS / "loginPage.png", QA / "implementation-login.png"),
    "register-1": (
        MOCKUPS / "registerPage1.png",
        QA / "implementation-register-1.png",
    ),
    "register-2": (
        MOCKUPS / "registerPage2.png",
        QA / "implementation-register-2.png",
    ),
    "register-3": (
        MOCKUPS / "registerPage3.png",
        QA / "implementation-register-3.png",
    ),
}


for name, (source_path, implementation_path) in PAIRS.items():
    with Image.open(source_path).convert("RGB") as source_image:
        source = source_image.resize(
            (1280, round(source_image.height * 1280 / source_image.width)),
            Image.Resampling.LANCZOS,
        )
    with Image.open(implementation_path).convert("RGB") as implementation_image:
        implementation = implementation_image.crop((0, 156, 1280, 2784))

    height = max(source.height, implementation.height)
    comparison = Image.new("RGB", (2568, height), "white")
    comparison.paste(source, (0, 0))
    comparison.paste(implementation, (1288, 0))
    ImageDraw.Draw(comparison).rectangle((1280, 0, 1287, height), fill="#5B50F6")
    comparison.save(QA / f"comparison-{name}.png", optimize=True)
