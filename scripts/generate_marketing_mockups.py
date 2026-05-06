#!/usr/bin/env python3

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path("/Users/castao/Desktop/PetMed/TailyDose")
OUTDIR = ROOT / "mockups" / "app-store-screenshots"
SIZE = (1284, 2778)
FONT_PATH = "/System/Library/Fonts/Helvetica.ttc"


SCREENS = [
    {
        "filename": "01-home-overview.png",
        "badge": "SEE TODAY CLEARLY",
        "headline": "All three pets.\nEvery dose.\nOne calm home screen.",
        "accent": (190, 141, 246),
        "kind": "home",
    },
    {
        "filename": "02-manage-routines.png",
        "badge": "KEEP IT ORGANIZED",
        "headline": "Track medications,\nweights, and routines\nwithout the chaos.",
        "accent": (182, 214, 112),
        "kind": "manage",
    },
    {
        "filename": "03-share-vet-records.png",
        "badge": "SHARE WITH CONFIDENCE",
        "headline": "Hand your vet a clean,\nready-to-send\nmedication summary.",
        "accent": (124, 214, 229),
        "kind": "share",
    },
    {
        "filename": "04-notifications.png",
        "badge": "NEVER MISS A DOSE",
        "headline": "Helpful reminder alerts\nkeep the next dose\nfront and center.",
        "accent": (244, 145, 184),
        "kind": "notification",
    },
    {
        "filename": "05-history-tracking.png",
        "badge": "STAY ACCOUNTABLE",
        "headline": "See what was taken,\nmissed, or skipped\nat a glance.",
        "accent": (255, 191, 107),
        "kind": "history",
    },
    {
        "filename": "06-pet-profiles.png",
        "badge": "BUILT FOR MULTI-PET HOMES",
        "headline": "Give every pet their own\nprofile, meds,\nand care details.",
        "accent": (120, 214, 180),
        "kind": "profiles",
    },
]


PETS = [
    {
        "name": "Olive",
        "type": "Goldendoodle",
        "color": (240, 171, 190),
        "meds": [("Carprofen", "1 chew", "7:30 AM"), ("Dental Gel", "pea-size dab", "8:00 AM")],
    },
    {
        "name": "Mochi",
        "type": "Ragdoll",
        "color": (170, 205, 255),
        "meds": [("Probiotic Powder", "1 scoop", "8:15 AM"), ("Calming Drops", "2 drops", "8:30 PM")],
    },
    {
        "name": "Juniper",
        "type": "Holland Lop",
        "color": (255, 210, 150),
        "meds": [("Gut Support Syringe", "0.6 mL", "9:00 AM"), ("Pain Relief Drops", "0.25 mL", "6:30 PM")],
    },
]


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_PATH, size=size)


def text_size(draw: ImageDraw.ImageDraw, text: str, text_font):
    left, top, right, bottom = draw.textbbox((0, 0), text, font=text_font)
    return right - left, bottom - top


def wrap_text(draw, text, text_font, max_width):
    lines = []
    for paragraph in text.split("\n"):
        words = paragraph.split()
        if not words:
            lines.append("")
            continue
        current = words[0]
        for word in words[1:]:
            trial = f"{current} {word}"
            if text_size(draw, trial, text_font)[0] <= max_width:
                current = trial
            else:
                lines.append(current)
                current = word
        lines.append(current)
    return lines


def draw_centered_text(draw, text, box, text_font, fill, spacing):
    lines = wrap_text(draw, text, text_font, box[2] - box[0])
    total_height = 0
    metrics = []
    for line in lines:
        width, height = text_size(draw, line, text_font)
        metrics.append((line, width, height))
        total_height += height
    total_height += spacing * max(0, len(lines) - 1)
    y = box[1] + ((box[3] - box[1]) - total_height) / 2
    for line, width, height in metrics:
        x = box[0] + ((box[2] - box[0]) - width) / 2
        draw.text((x, y), line, font=text_font, fill=fill)
        y += height + spacing


def rounded_shadow(base, box, radius, shadow_color, blur_radius, offset):
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shifted = (box[0] + offset[0], box[1] + offset[1], box[2] + offset[0], box[3] + offset[1])
    shadow_draw.rounded_rectangle(shifted, radius=radius, fill=shadow_color)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur_radius))
    base.alpha_composite(shadow)


def make_background(accent):
    image = Image.new("RGBA", SIZE, (0, 0, 0, 255))
    pixels = image.load()
    top = (12, 16, 34)
    bottom = (24, 18, 50)
    for y in range(SIZE[1]):
        ratio = y / (SIZE[1] - 1)
        row = tuple(int(top[i] * (1 - ratio) + bottom[i] * ratio) for i in range(3))
        for x in range(SIZE[0]):
            pixels[x, y] = row + (255,)

    glow = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse((760, 120, 1220, 580), fill=accent + (55,))
    glow_draw.ellipse((80, 1750, 460, 2130), fill=(255, 255, 255, 28))
    glow = glow.filter(ImageFilter.GaussianBlur(55))
    image.alpha_composite(glow)
    return image


def draw_badge(draw, text, accent):
    badge_font = font(34)
    width, height = text_size(draw, text, badge_font)
    box = (SIZE[0] // 2 - width // 2 - 44, 160, SIZE[0] // 2 + width // 2 + 44, 160 + height + 28)
    draw.rounded_rectangle(box, radius=32, fill=accent + (50,), outline=accent + (120,), width=2)
    draw.text((box[0] + 44, box[1] + 13), text, font=badge_font, fill=(247, 244, 250))


def draw_phone_shell(base):
    shell = (225, 820, 1065, 2550)
    rounded_shadow(base, shell, 88, (0, 0, 0, 150), 35, (0, 24))
    draw = ImageDraw.Draw(base)
    draw.rounded_rectangle(shell, radius=88, fill=(7, 9, 15), outline=(235, 238, 244, 200), width=5)
    screen = (257, 852, 1033, 2518)
    draw.rounded_rectangle(screen, radius=70, fill=(14, 17, 28))
    island = (482, 895, 808, 953)
    draw.rounded_rectangle(island, radius=30, fill=(4, 4, 4))
    return screen


def draw_status_bar(draw, screen, light=True):
    fill = (242, 245, 249) if light else (224, 228, 236)
    draw.text((screen[0] + 44, screen[1] + 36), "9:41", font=font(34), fill=fill)
    draw.rounded_rectangle((screen[2] - 94, screen[1] + 40, screen[2] - 38, screen[1] + 72), radius=16, outline=fill, width=3)
    draw.rectangle((screen[2] - 36, screen[1] + 49, screen[2] - 30, screen[1] + 63), fill=fill)


def draw_avatar(draw, center, color):
    x, y = center
    draw.ellipse((x - 24, y - 24, x + 24, y + 24), fill=color + (255,))
    draw.ellipse((x - 12, y - 6, x + 12, y + 14), fill=(255, 255, 255, 45))
    draw.ellipse((x - 18, y - 18, x - 6, y - 6), fill=(255, 255, 255, 50))


def draw_home_screen(draw, screen, notification=False):
    inner = Image.new("RGBA", (screen[2] - screen[0], screen[3] - screen[1]), (0, 0, 0, 0))
    inner_draw = ImageDraw.Draw(inner)

    for y in range(inner.size[1]):
        ratio = y / (inner.size[1] - 1)
        color = (
            int(17 * (1 - ratio) + 28 * ratio),
            int(28 * (1 - ratio) + 22 * ratio),
            int(42 * (1 - ratio) + 52 * ratio),
            255,
        )
        inner_draw.line((0, y, inner.size[0], y), fill=color)

    inner_draw.text((44, 118), "Today", font=font(52), fill=(243, 244, 249))
    inner_draw.text((44, 182), "3 pets • 6 reminders", font=font(25), fill=(159, 168, 186))

    y = 256
    for pet in PETS:
        for medicine, dosage, time_text in pet["meds"][:1]:
            box = (32, y, inner.size[0] - 32, y + 194)
            inner_draw.rounded_rectangle(box, radius=36, fill=(31, 36, 58), outline=(255, 255, 255, 10))
            draw_avatar(inner_draw, (86, y + 60), pet["color"])
            inner_draw.text((132, y + 32), time_text, font=font(34), fill=(244, 245, 249))
            inner_draw.text((132, y + 78), f"{dosage} {medicine}", font=font(28), fill=(219, 224, 235))
            inner_draw.text((132, y + 118), pet["name"], font=font(24), fill=(142, 152, 172))
            inner_draw.rounded_rectangle((box[2] - 92, y + 42, box[2] - 44, y + 90), radius=24, outline=(106, 185, 168), width=4)
            y += 218

    if notification:
        banner = (30, 180, inner.size[0] - 30, 308)
        inner_draw.rounded_rectangle(banner, radius=30, fill=(126, 58, 102))
        inner_draw.text((62, 208), "Medication Reminder", font=font(28), fill=(252, 247, 251))
        inner_draw.text((62, 246), "Juniper • Pain Relief Drops at 6:30 PM", font=font(22), fill=(243, 218, 234))

    return inner


def draw_manage_screen(draw, screen):
    inner = Image.new("RGBA", (screen[2] - screen[0], screen[3] - screen[1]), (18, 20, 30, 255))
    inner_draw = ImageDraw.Draw(inner)
    inner_draw.text((44, 118), "Pets", font=font(52), fill=(243, 244, 249))
    inner_draw.text((44, 182), "Profiles, meds, and weight history", font=font(24), fill=(159, 168, 186))

    y = 250
    for pet in PETS:
        box = (34, y, inner.size[0] - 34, y + 250)
        inner_draw.rounded_rectangle(box, radius=34, fill=(34, 40, 60))
        draw_avatar(inner_draw, (92, y + 80), pet["color"])
        inner_draw.text((146, y + 42), pet["name"], font=font(32), fill=(245, 246, 250))
        inner_draw.text((146, y + 84), pet["type"], font=font(24), fill=(162, 170, 189))
        inner_draw.text((146, y + 124), f"{len(pet['meds'])} active medications", font=font(22), fill=(207, 213, 226))
        inner_draw.rounded_rectangle((146, y + 164, 308, y + 208), radius=20, fill=(56, 78, 103))
        inner_draw.text((172, y + 176), "Weight tracked", font=font(18), fill=(222, 235, 248))
        inner_draw.rounded_rectangle((326, y + 164, 482, y + 208), radius=20, fill=(72, 83, 56))
        inner_draw.text((352, y + 176), "Refills ready", font=font(18), fill=(232, 239, 221))
        y += 284

    return inner


def draw_share_screen(draw, screen):
    inner = Image.new("RGBA", (screen[2] - screen[0], screen[3] - screen[1]), (18, 20, 30, 255))
    inner_draw = ImageDraw.Draw(inner)
    inner_draw.text((44, 118), "Vet Summary", font=font(48), fill=(243, 244, 249))
    inner_draw.text((44, 182), "Ready to text or email before the visit", font=font(24), fill=(159, 168, 186))

    card = (36, 262, inner.size[0] - 36, 1120)
    inner_draw.rounded_rectangle(card, radius=38, fill=(246, 244, 238))
    inner_draw.text((74, 316), "Medication Snapshot", font=font(34), fill=(45, 47, 57))
    inner_draw.text((74, 368), "Prepared for Westside Animal Hospital", font=font(22), fill=(104, 108, 122))

    y = 450
    for pet in PETS:
        inner_draw.text((74, y), pet["name"], font=font(28), fill=(42, 44, 54))
        y += 42
        for medicine, dosage, time_text in pet["meds"]:
            inner_draw.text((92, y), f"• {medicine} — {dosage} at {time_text}", font=font(22), fill=(92, 95, 109))
            y += 34
        y += 18

    cta = (84, 1180, inner.size[0] - 84, 1280)
    inner_draw.rounded_rectangle(cta, radius=28, fill=(96, 153, 181))
    inner_draw.text((cta[0] + 170, cta[1] + 28), "Share PDF with vet", font=font(28), fill=(244, 248, 251))

    return inner


def draw_history_screen(draw, screen):
    inner = Image.new("RGBA", (screen[2] - screen[0], screen[3] - screen[1]), (18, 20, 30, 255))
    inner_draw = ImageDraw.Draw(inner)
    inner_draw.text((44, 118), "History", font=font(48), fill=(243, 244, 249))
    inner_draw.text((44, 182), "Recent doses and adherence", font=font(24), fill=(159, 168, 186))

    month = (40, 258, inner.size[0] - 40, 726)
    inner_draw.rounded_rectangle(month, radius=34, fill=(31, 36, 58))
    inner_draw.text((72, 304), "April 2026", font=font(28), fill=(241, 243, 248))

    days = ["S", "M", "T", "W", "T", "F", "S"]
    for index, day in enumerate(days):
        inner_draw.text((86 + index * 92, 356), day, font=font(18), fill=(142, 152, 172))

    statuses = [
        (0, 0, (92, 174, 146)),
        (1, 0, (92, 174, 146)),
        (2, 0, (214, 166, 96)),
        (3, 0, (201, 98, 118)),
        (4, 0, (92, 174, 146)),
        (5, 0, (92, 174, 146)),
        (6, 0, (214, 166, 96)),
        (1, 1, (92, 174, 146)),
        (2, 1, (92, 174, 146)),
        (3, 1, (201, 98, 118)),
        (4, 1, (92, 174, 146)),
    ]
    for column, row, color in statuses:
        x = 78 + column * 92
        y = 404 + row * 92
        inner_draw.rounded_rectangle((x, y, x + 60, y + 60), radius=22, fill=color)

    list_y = 790
    items = [
        ("Taken", "Olive • Carprofen • 7:30 AM", (92, 174, 146)),
        ("Missed", "Juniper • Pain Relief Drops • 6:30 PM", (201, 98, 118)),
        ("Skipped", "Mochi • Calming Drops • 8:30 PM", (214, 166, 96)),
    ]
    for title, detail, color in items:
        box = (40, list_y, inner.size[0] - 40, list_y + 132)
        inner_draw.rounded_rectangle(box, radius=30, fill=(31, 36, 58))
        inner_draw.ellipse((72, list_y + 40, 92, list_y + 60), fill=color)
        inner_draw.text((116, list_y + 28), title, font=font(24), fill=(241, 243, 248))
        inner_draw.text((116, list_y + 66), detail, font=font(20), fill=(164, 172, 190))
        list_y += 152

    return inner


def draw_profiles_screen(draw, screen):
    inner = Image.new("RGBA", (screen[2] - screen[0], screen[3] - screen[1]), (18, 20, 30, 255))
    inner_draw = ImageDraw.Draw(inner)
    inner_draw.text((44, 118), "Pet Profiles", font=font(48), fill=(243, 244, 249))
    inner_draw.text((44, 182), "Health notes that stay organized", font=font(24), fill=(159, 168, 186))

    hero = PETS[0]
    card = (40, 258, inner.size[0] - 40, 990)
    inner_draw.rounded_rectangle(card, radius=38, fill=(31, 36, 58))
    draw_avatar(inner_draw, (120, 350), hero["color"])
    inner_draw.text((178, 318), hero["name"], font=font(34), fill=(245, 246, 250))
    inner_draw.text((178, 364), hero["type"], font=font(24), fill=(162, 170, 189))
    inner_draw.text((76, 448), "Weight", font=font(22), fill=(161, 171, 190))
    inner_draw.text((76, 484), "42 lb", font=font(28), fill=(241, 243, 248))
    inner_draw.text((252, 448), "Breed", font=font(22), fill=(161, 171, 190))
    inner_draw.text((252, 484), "Mini Goldendoodle", font=font(28), fill=(241, 243, 248))

    inner_draw.text((76, 574), "Current medications", font=font(24), fill=(241, 243, 248))
    y = 628
    for medicine, dosage, time_text in hero["meds"]:
        row = (76, y, inner.size[0] - 76, y + 108)
        inner_draw.rounded_rectangle(row, radius=24, fill=(41, 47, 73))
        inner_draw.text((102, y + 24), medicine, font=font(24), fill=(243, 244, 249))
        inner_draw.text((102, y + 58), f"{dosage} • {time_text}", font=font(20), fill=(170, 178, 196))
        y += 126

    note = (40, 1040, inner.size[0] - 40, 1290)
    inner_draw.rounded_rectangle(note, radius=34, fill=(31, 36, 58))
    inner_draw.text((76, 1088), "Care note", font=font(24), fill=(241, 243, 248))
    inner_draw.text((76, 1132), "Hides tablets best in peanut butter treats.", font=font(22), fill=(166, 174, 191))

    return inner


def place_screen(base, screen, content):
    base.alpha_composite(content, dest=(screen[0], screen[1]))


def build_screen(spec):
    accent = spec["accent"]
    image = make_background(accent)
    draw = ImageDraw.Draw(image)

    draw_badge(draw, spec["badge"], accent)
    draw_centered_text(draw, spec["headline"], (120, 300, SIZE[0] - 120, 760), font(76), (247, 245, 250), 10)

    screen = draw_phone_shell(image)
    draw_status_bar(draw, screen)

    if spec["kind"] == "home":
        content = draw_home_screen(draw, screen)
    elif spec["kind"] == "manage":
        content = draw_manage_screen(draw, screen)
    elif spec["kind"] == "share":
        content = draw_share_screen(draw, screen)
    elif spec["kind"] == "history":
        content = draw_history_screen(draw, screen)
    elif spec["kind"] == "profiles":
        content = draw_profiles_screen(draw, screen)
    else:
        content = draw_home_screen(draw, screen, notification=True)

    place_screen(image, screen, content)
    return image.convert("RGB")


def main():
    OUTDIR.mkdir(parents=True, exist_ok=True)
    for spec in SCREENS:
        image = build_screen(spec)
        image.save(OUTDIR / spec["filename"], quality=95)


if __name__ == "__main__":
    main()
