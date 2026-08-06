from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "mockups" / "light_mode" / "loginPage.png"
OUTPUT = SOURCE.parent
AUTH_CROPS = OUTPUT / "auth_crops"


def crop(name: str, box: tuple[int, int, int, int]) -> None:
    with Image.open(SOURCE) as image:
        image.crop(box).save(OUTPUT / name, optimize=True)


crop("auth-brand-icon.png", (382, 136, 473, 228))
crop("login-feature.png", (96, 788, 238, 930))


def crop_mascot(source_name: str, output_name: str) -> None:
    with Image.open(OUTPUT / source_name).convert("RGB") as image:
        difference = ImageChops.difference(
            image, Image.new("RGB", image.size, "white")
        ).convert("L")
        mask = difference.point(lambda value: 255 if value > 8 else 0)
        bounds = mask.getbbox()
        if bounds is None:
            raise ValueError(f"No mascot artwork found in {source_name}")
        left, top, right, bottom = bounds
        padding = 20
        box = (
            max(0, left - padding),
            max(0, top - padding),
            min(image.width, right + padding),
            min(image.height, bottom + padding),
        )
        AUTH_CROPS.mkdir(exist_ok=True)
        image.crop(box).save(AUTH_CROPS / output_name, optimize=True)


crop_mascot("loginPage-dog.png", "login-dog.png")
crop_mascot("registerPage1-dog.png", "register-step-1-dog.png")
crop_mascot("registerPage2-dog.png", "register-step-2-dog.png")
crop_mascot("registerPage3-dog.png", "register-step-3-dog.png")
