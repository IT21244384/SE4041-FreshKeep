"""Generates the asset catalogs (colours with light/dark variants, app icon, launch logo)
for the iOS and visionOS targets. Run:  python tools/make_assets.py
Requires Pillow."""
import json
import math
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# name: (light hex, dark hex)
COLORS = {
    "AccentColor": ("#2BAE66", "#4CD08A"),
    "Brand": ("#2BAE66", "#3CC27A"),
    "BrandDeep": ("#0F6B47", "#1F8A5C"),
    "Citrus": ("#F5A524", "#FFB84D"),
    "CardBackground": ("#FFFFFF", "#1C2320"),
    "AppBackground": ("#F4F6F1", "#0E1311"),
    "LaunchBackground": ("#F4F6F1", "#0E1311"),
    "FreshGood": ("#2BAE66", "#4CD08A"),
    "FreshSoon": ("#E8A317", "#F7BE45"),
    "FreshToday": ("#EF6C2F", "#FF8A50"),
    "FreshExpired": ("#D93D3D", "#FF6B6B"),
}


def hex_to_components(value):
    value = value.lstrip("#")
    r, g, b = (int(value[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return {"red": f"{r:.3f}", "green": f"{g:.3f}", "blue": f"{b:.3f}", "alpha": "1.000"}


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


def color_set(light, dark):
    return {
        "colors": [
            {"idiom": "universal", "color": {"color-space": "srgb", "components": hex_to_components(light)}},
            {"idiom": "universal",
             "appearances": [{"appearance": "luminosity", "value": "dark"}],
             "color": {"color-space": "srgb", "components": hex_to_components(dark)}},
        ],
        "info": {"author": "xcode", "version": 1},
    }


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def draw_icon(size=1024, transparent=False):
    """Leaf inside a freshness ring on a green gradient."""
    s = size * 4  # supersample for smooth edges
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    if not transparent:
        top, bottom = (52, 196, 120), (12, 98, 66)
        grad = Image.new("RGBA", (s, s))
        gd = ImageDraw.Draw(grad)
        for y in range(s):
            gd.line([(0, y), (s, y)], fill=lerp(top, bottom, y / s) + (255,))
        img = grad
    d = ImageDraw.Draw(img)
    cx = cy = s / 2

    # Freshness ring: pale track + bright arc (about 3/4 full).
    r = s * 0.34
    w = s * 0.06
    box = [cx - r, cy - r, cx + r, cy + r]
    d.ellipse(box, outline=(255, 255, 255, 70), width=int(w))
    d.arc(box, start=-90, end=180, fill=(255, 214, 102, 255), width=int(w))
    # Rounded cap at both arc ends.
    for angle in (-90, 180):
        a = math.radians(angle)
        px, py = cx + (r - w / 2) * math.cos(a), cy + (r - w / 2) * math.sin(a)
        d.ellipse([px - w / 2, py - w / 2, px + w / 2, py + w / 2], fill=(255, 214, 102, 255))

    # Leaf: two circle arcs intersecting, rotated 45 degrees.
    leaf = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ld = ImageDraw.Draw(leaf)
    lr = s * 0.30
    off = s * 0.15
    mask_a = Image.new("L", (s, s), 0)
    mask_b = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask_a).ellipse([cx - lr - off, cy - lr, cx + lr - off, cy + lr], fill=255)
    ImageDraw.Draw(mask_b).ellipse([cx - lr + off, cy - lr, cx + lr + off, cy + lr], fill=255)
    from PIL import ImageChops
    mask = ImageChops.multiply(mask_a, mask_b)
    ld.bitmap((0, 0), mask, fill=(255, 255, 255, 255))
    # Midrib.
    ld.line([(cx, cy - lr * 0.75), (cx, cy + lr * 0.75)], fill=(46, 170, 104, 255), width=int(s * 0.022))
    leaf = leaf.rotate(-40, resample=Image.BICUBIC, center=(cx, cy))
    shadow = leaf.split()[3].filter(ImageFilter.GaussianBlur(s * 0.012))
    shadow_layer = Image.new("RGBA", (s, s), (0, 40, 20, 0))
    shadow_layer.putalpha(shadow.point(lambda v: int(v * 0.35)))
    img = Image.alpha_composite(img, shadow_layer.transform((s, s), Image.AFFINE, (1, 0, 0, 0, 1, -s * 0.01)))
    img = Image.alpha_composite(img, leaf)
    img = img.resize((size, size), Image.LANCZOS)
    if not transparent:
        img = img.convert("RGB")
    return img


def build_catalog(path, include_launch=True, platform="ios"):
    write_json(os.path.join(path, "Contents.json"), {"info": {"author": "xcode", "version": 1}})
    for name, (light, dark) in COLORS.items():
        write_json(os.path.join(path, f"{name}.colorset", "Contents.json"), color_set(light, dark))

    if platform == "ios":
        icon_dir = os.path.join(path, "AppIcon.appiconset")
        os.makedirs(icon_dir, exist_ok=True)
        draw_icon().save(os.path.join(icon_dir, "AppIcon-1024.png"))
        write_json(os.path.join(icon_dir, "Contents.json"), {
            "images": [{"filename": "AppIcon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
            "info": {"author": "xcode", "version": 1},
        })
    else:
        # visionOS icons are a solid-image stack with up to three layers.
        stack = os.path.join(path, "AppIcon.solidimagestack")
        write_json(os.path.join(stack, "Contents.json"), {
            "info": {"author": "xcode", "version": 1},
            "layers": [{"filename": "Front.solidimagestacklayer"}, {"filename": "Back.solidimagestacklayer"}],
        })
        back = draw_icon()
        front = draw_icon(transparent=True)
        for layer, image in (("Back", back), ("Front", front)):
            layer_dir = os.path.join(stack, f"{layer}.solidimagestacklayer")
            write_json(os.path.join(layer_dir, "Contents.json"), {"info": {"author": "xcode", "version": 1}})
            content = os.path.join(layer_dir, "Content.imageset")
            os.makedirs(content, exist_ok=True)
            image.save(os.path.join(content, f"{layer}.png"))
            write_json(os.path.join(content, "Contents.json"), {
                "images": [{"filename": f"{layer}.png", "idiom": "vision", "scale": "2x"}],
                "info": {"author": "xcode", "version": 1},
            })

    if include_launch:
        logo_dir = os.path.join(path, "LaunchLogo.imageset")
        os.makedirs(logo_dir, exist_ok=True)
        logo = draw_icon(360)
        # Round the corners so the launch logo looks like the icon.
        mask = Image.new("L", logo.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, 359, 359], radius=80, fill=255)
        rounded = Image.new("RGBA", logo.size)
        rounded.paste(logo, (0, 0), mask)
        rounded.save(os.path.join(logo_dir, "LaunchLogo.png"))
        write_json(os.path.join(logo_dir, "Contents.json"), {
            "images": [{"filename": "LaunchLogo.png", "idiom": "universal", "scale": "3x"}],
            "info": {"author": "xcode", "version": 1},
        })


if __name__ == "__main__":
    build_catalog(os.path.join(ROOT, "FreshKeep", "Resources", "Assets.xcassets"))
    build_catalog(os.path.join(ROOT, "FreshKeepSpatial", "Resources", "Assets.xcassets"),
                  include_launch=False, platform="visionos")
    os.makedirs(os.path.join(ROOT, "docs", "images"), exist_ok=True)
    draw_icon().save(os.path.join(ROOT, "docs", "images", "app-icon.png"))
    print("Assets generated")
