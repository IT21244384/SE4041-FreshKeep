"""Draws the architecture and user-flow diagrams used in the documentation.
Run: python tools/diagrams.py   (requires Pillow; uses Windows fonts if present)"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "images")
os.makedirs(OUT, exist_ok=True)

FONT_DIR = "C:/Windows/Fonts"


def font(size, bold=False):
    for name in (["segoeuib.ttf", "arialbd.ttf"] if bold else ["segoeui.ttf", "arial.ttf"]):
        path = os.path.join(FONT_DIR, name)
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


GREEN = (43, 174, 102)
DEEP = (15, 107, 71)
CITRUS = (245, 165, 36)
INK = (17, 24, 20)
GREY = (95, 107, 100)
LIGHT = (233, 238, 230)
BG = (255, 255, 255)
BLUE = (64, 120, 200)
PURPLE = (120, 90, 190)


def box(d, xy, title, lines=(), fill=LIGHT, outline=GREEN, title_color=INK, radius=18, size=26):
    d.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=3)
    x0, y0, x1, y1 = xy
    d.text(((x0 + x1) / 2, y0 + 16), title, font=font(size, True), fill=title_color, anchor="ma")
    y = y0 + 16 + size + 12
    for line in lines:
        d.text(((x0 + x1) / 2, y), line, font=font(size - 6), fill=GREY, anchor="ma")
        y += size + 2


def arrow(d, start, end, color=GREY, width=4, label=None):
    d.line([start, end], fill=color, width=width)
    import math
    ang = math.atan2(end[1] - start[1], end[0] - start[0])
    size = 16
    p1 = (end[0] - size * math.cos(ang - 0.4), end[1] - size * math.sin(ang - 0.4))
    p2 = (end[0] - size * math.cos(ang + 0.4), end[1] - size * math.sin(ang + 0.4))
    d.polygon([end, p1, p2], fill=color)
    if label:
        mx, my = (start[0] + end[0]) / 2, (start[1] + end[1]) / 2
        f = font(20)
        w = d.textlength(label, font=f)
        d.rectangle([mx - w / 2 - 6, my - 14, mx + w / 2 + 6, my + 14], fill=BG)
        d.text((mx, my), label, font=f, fill=GREY, anchor="mm")


def architecture():
    W, H = 2000, 1400
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.text((W / 2, 40), "FreshKeep — system architecture (MVVM + shared core)", font=font(44, True), fill=INK, anchor="ma")

    # Layer bands
    bands = [
        (130, 400, "Presentation (SwiftUI Views)", (232, 246, 238)),
        (430, 640, "View models & state", (255, 246, 228)),
        (670, 940, "Services (Apple frameworks)", (232, 240, 252)),
        (970, 1250, "Domain & data", (240, 236, 250)),
    ]
    for y0, y1, label, color in bands:
        d.rounded_rectangle([40, y0, W - 40, y1], radius=24, fill=color)
        d.text((W - 70, y0 + 10), label, font=font(24, True), fill=GREY, anchor="ra")

    views = [("Onboarding", ["3-page intro"]), ("Pantry", ["List, search,", "swipe, carousel"]), ("Item Detail", ["ring, tip,", "freeze / eaten"]),
             ("Scan", ["camera, photos,", "results"]), ("Insights", ["Swift Charts,", "recipes"]), ("Settings", ["reminders,", "theme, data"])]
    x = 80
    for title, lines in views:
        box(d, (x, 200, x + 290, 380), title, lines, fill=BG)
        x += 310
    box(d, (80, 470, 520, 620), "ScanViewModel", ["@Observable, async Vision", "pipeline, cancellation"], fill=BG, outline=CITRUS)
    box(d, (560, 470, 1000, 620), "ItemDraft", ["form state, validation,", "expiry estimation"], fill=BG, outline=CITRUS)
    box(d, (1040, 470, 1480, 620), "@Query / @AppStorage", ["SwiftData-driven", "reactive lists"], fill=BG, outline=CITRUS)
    box(d, (1520, 470, 1920, 620), "AppServices", ["dependency container", "(real vs mock)"], fill=BG, outline=CITRUS)

    services = [("VisionFoodClassifier", ["VNClassifyImageRequest", "(Core ML, on-device)"]), ("VisionLabelReader", ["VNRecognizeTextRequest", "(OCR)"]),
                ("NotificationService", ["UserNotifications", "calendar triggers"]), ("ImagePipeline", ["ImageIO downsampling", "+ NSCache"])]
    x = 80
    for title, lines in services:
        box(d, (x, 740, x + 440, 920), title, lines, fill=BG, outline=BLUE)
        x += 460

    box(d, (80, 1040, 940, 1230), "FreshKeepCore (Swift package — 33 tests)",
        ["ShelfLifeCatalog · FoodMatcher · ExpiryDateParser", "FreshnessCalculator · WasteInsights · RecipeSuggester · ReminderPlanner"], fill=BG, outline=PURPLE, size=26)
    box(d, (980, 1040, 1440, 1230), "SwiftData store", ["@Model PantryItem (read via @Query)", "photos: external storage"], fill=BG, outline=PURPLE)
    box(d, (1480, 1040, 1920, 1230), "visionOS app", ["RealityKit volume +", "ImmersiveSpace (shared)"], fill=BG, outline=PURPLE)

    for x in (300, 780, 1260, 1600):
        arrow(d, (x, 400), (x, 465))
        arrow(d, (x, 640), (x, 735))
    arrow(d, (510, 940), (510, 1035))
    arrow(d, (1600, 940), (1600, 1035))
    d.text((W / 2, H - 70), "Everything runs on the device — no backend, no account, works offline.", font=font(26), fill=GREY, anchor="ma")
    img.save(os.path.join(OUT, "architecture.png"))


def user_flow():
    W, H = 2200, 1100
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.text((W / 2, 36), "FreshKeep — navigation & user flow", font=font(44, True), fill=INK, anchor="ma")
    nodes = {
        "launch": ((80, 470, 330, 590), "App launch", ["first run?"], LIGHT, GREY),
        "onb": ((420, 150, 700, 290), "Onboarding", ["3 pages +", "notification prompt"], BG, CITRUS),
        "pantry": ((420, 470, 700, 610), "Pantry (tab 1)", ["NavigationStack"], BG, GREEN),
        "detail": ((820, 330, 1100, 470), "Item Detail", ["eat / freeze / waste"], BG, GREEN),
        "add": ((820, 620, 1100, 760), "Add / Edit Item", ["sheet, pre-filled"], BG, GREEN),
        "scan": ((420, 820, 700, 960), "Scan (tab 2)", ["Food | Date label"], BG, BLUE),
        "results": ((820, 880, 1100, 1020), "Scan results", ["ranked matches"], BG, BLUE),
        "recipe": ((1240, 330, 1520, 470), "Recipe detail", ["cook-along steps"], BG, CITRUS),
        "insights": ((1240, 620, 1520, 760), "Insights (tab 3)", ["charts, stats"], BG, CITRUS),
        "settings": ((1640, 620, 1920, 760), "Settings (tab 4)", ["reminders, theme"], BG, GREY),
        "notif": ((1640, 150, 1920, 290), "Reminder", ["notification → app"], LIGHT, CITRUS),
    }
    for key, (xy, title, lines, fill, outline) in nodes.items():
        box(d, xy, title, lines, fill=fill, outline=outline, size=26)

    def mid(key, side):
        x0, y0, x1, y1 = nodes[key][0]
        return {"l": (x0, (y0 + y1) / 2), "r": (x1, (y0 + y1) / 2), "t": ((x0 + x1) / 2, y0), "b": ((x0 + x1) / 2, y1)}[side]

    arrow(d, mid("launch", "r"), mid("onb", "l"), label="yes")
    arrow(d, mid("launch", "r"), mid("pantry", "l"), label="no")
    arrow(d, mid("onb", "b"), mid("pantry", "t"))
    arrow(d, mid("pantry", "r"), mid("detail", "l"), label="tap row")
    arrow(d, mid("pantry", "r"), mid("add", "l"), label="+")
    arrow(d, mid("pantry", "b"), mid("scan", "t"), label="tab")
    arrow(d, mid("scan", "r"), mid("results", "l"), label="photo")
    arrow(d, mid("results", "t"), mid("add", "b"), label="pick match")
    arrow(d, mid("detail", "r"), mid("recipe", "l"), label="use it up")
    arrow(d, mid("insights", "t"), mid("recipe", "b"))
    arrow(d, mid("detail", "b"), mid("add", "t"), label="edit")
    arrow(d, mid("insights", "r"), mid("settings", "l"), label="tab")
    arrow(d, mid("notif", "l"), (960, 330), label="tap")
    d.text((W / 2, H - 50), "iPhone: TabView · iPad / landscape: NavigationSplitView sidebar · sheets for create/edit",
           font=font(24), fill=GREY, anchor="ma")
    img.save(os.path.join(OUT, "user-flow.png"))


if __name__ == "__main__":
    architecture()
    user_flow()
    print("Diagrams written to docs/images")
