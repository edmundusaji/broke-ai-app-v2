from pathlib import Path
import json

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_PATH = ROOT / "assets/app-icon/icon-2.png"


def main() -> None:
    source = Image.open(SOURCE_PATH).convert("RGB")
    resample = Image.Resampling.LANCZOS

    def save_png(path: Path, size: int) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        source.resize((size, size), resample).save(path, "PNG", optimize=True)

    android_res = ROOT / "android/app/src/main/res"
    android_sizes = {
        "mipmap-mdpi/ic_launcher.png": 48,
        "mipmap-hdpi/ic_launcher.png": 72,
        "mipmap-xhdpi/ic_launcher.png": 96,
        "mipmap-xxhdpi/ic_launcher.png": 144,
        "mipmap-xxxhdpi/ic_launcher.png": 192,
    }
    for relative, size in android_sizes.items():
        save_png(android_res / relative, size)
    save_png(android_res / "drawable-nodpi/launch_image.png", 240)

    ios_icons = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((ios_icons / "Contents.json").read_text())
    for item in contents["images"]:
        filename = item.get("filename")
        if filename is None:
            continue
        points = float(item["size"].split("x")[0])
        scale = int(item["scale"].removesuffix("x"))
        save_png(ios_icons / filename, round(points * scale))

    ios_launch = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    for filename, size in {
        "LaunchImage.png": 168,
        "LaunchImage@2x.png": 336,
        "LaunchImage@3x.png": 504,
    }.items():
        save_png(ios_launch / filename, size)

    macos_icons = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for path in macos_icons.glob("app_icon_*.png"):
        save_png(path, int(path.stem.rsplit("_", 1)[1]))

    for relative, size in {
        "web/favicon.png": 48,
        "web/icons/Icon-192.png": 192,
        "web/icons/Icon-512.png": 512,
        "web/icons/Icon-maskable-192.png": 192,
        "web/icons/Icon-maskable-512.png": 512,
    }.items():
        save_png(ROOT / relative, size)

    source.save(
        ROOT / "windows/runner/resources/app_icon.ico",
        format="ICO",
        sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )


if __name__ == "__main__":
    main()
