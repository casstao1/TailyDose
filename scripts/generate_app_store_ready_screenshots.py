#!/usr/bin/env python3

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path("/Users/castao/Desktop/PetMed/TailyDose")
SOURCE_DIR = ROOT / "mockups" / "simulator-screenshots"
OUTDIR = ROOT / "mockups" / "app-store-ready"
SIZE = (1284, 2778)
FONT_PATH = "/System/Library/Fonts/Helvetica.ttc"


SCREENS = [
    {
        "filename": "01-home-overview.png",
        "source": "01-home-actual.png",
        "eyebrow": "TODAY AT A GLANCE",
        "headline": "All your pets.\nAll today’s meds.\nOne calm screen.",
        "accent": (169, 144, 240),
    },
    {
        "filename": "02-manage-pets-and-meds.png",
        "source": "02-manage-actual.png",
        "eyebrow": "STAY ORGANIZED",
        "headline": "Profiles, medications,\nand reminders\nkept in sync.",
        "accent": (194, 212, 121),
    },
    {
        "filename": "03-history-tracking.png",
        "source": "03-history-actual.png",
        "eyebrow": "TRACK ADHERENCE",
        "headline": "Taken, missed,\nor skipped.\nAlways clear.",
        "accent": (245, 182, 103),
    },
    {
        "filename": "04-share-with-vet.png",
        "source": "05-share-actual.png",
        "eyebrow": "SHARE WITH VETS",
        "headline": "Send a clean\nmedication summary\nbefore the visit.",
        "accent": (130, 210, 226),
    },
    {
        "filename": "05-lock-screen-alerts.png",
        "source": "07-lockscreen-notification-bright.png",
        "eyebrow": "NEVER MISS A DOSE",
        "headline": "Lock screen alerts\nwhen the next dose\nis due.",
        "accent": (242, 149, 186),
    },
]


def font(size: int, bold: bool = False):
    return ImageFont.truetype(FONT_PATH, size=size, index=1 if bold else 0)


def text_size(draw, text, text_font):
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


def make_background(accent):
    image = Image.new("RGBA", SIZE, (0, 0, 0, 255))
    pixels = image.load()
    top = (13, 15, 30)
    bottom = (27, 19, 48)
    for y in range(SIZE[1]):
        ratio = y / (SIZE[1] - 1)
        row = tuple(int(top[i] * (1 - ratio) + bottom[i] * ratio) for i in range(3))
        for x in range(SIZE[0]):
            pixels[x, y] = row + (255,)

    glow = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse((740, 90, 1250, 620), fill=accent + (48,))
    glow_draw.ellipse((80, 2060, 460, 2450), fill=(255, 255, 255, 18))
    glow = glow.filter(ImageFilter.GaussianBlur(72))
    image.alpha_composite(glow)
    return image


def draw_eyebrow(draw, text, accent):
    eyebrow_font = font(29, bold=True)
    width, height = text_size(draw, text, eyebrow_font)
    box = (
        SIZE[0] // 2 - width // 2 - 34,
        150,
        SIZE[0] // 2 + width // 2 + 34,
        150 + height + 18,
    )
    draw.rounded_rectangle(box, radius=24, fill=accent + (42,), outline=accent + (92,), width=2)
    draw.text((box[0] + 34, box[1] + 8), text, font=eyebrow_font, fill=(246, 243, 249))


def draw_headline(draw, text):
    headline_font = font(72)
    lines = wrap_text(draw, text, headline_font, 980)
    metrics = [(*text_size(draw, line, headline_font), line) for line in lines]
    total_height = sum(height for _, height, _ in metrics) + max(0, len(metrics) - 1) * 6
    y = 305
    for width, height, line in metrics:
        x = (SIZE[0] - width) / 2
        draw.text((x, y), line, font=headline_font, fill=(247, 245, 249))
        y += height + 6


def rounded_shadow(base, box, radius, fill, blur_radius, offset):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    shifted = (box[0] + offset[0], box[1] + offset[1], box[2] + offset[0], box[3] + offset[1])
    draw.rounded_rectangle(shifted, radius=radius, fill=fill)
    layer = layer.filter(ImageFilter.GaussianBlur(blur_radius))
    base.alpha_composite(layer)


def fit_source(source, target_size):
    target_ratio = target_size[0] / target_size[1]
    source_ratio = source.width / source.height
    if source_ratio > target_ratio:
        new_height = source.height
        new_width = int(new_height * target_ratio)
        left = (source.width - new_width) // 2
        source = source.crop((left, 0, left + new_width, new_height))
    else:
        new_width = source.width
        new_height = int(new_width / target_ratio)
        top = (source.height - new_height) // 2
        source = source.crop((0, top, new_width, top + new_height))
    return source.resize(target_size, Image.Resampling.LANCZOS)


def add_screen_card(base, source_path):
    card_box = (200, 760, 1120, 2758)
    rounded_shadow(base, card_box, 72, (0, 0, 0, 88), 26, (0, 20))

    card_layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(card_layer)
    draw.rounded_rectangle(card_box, radius=72, fill=(255, 255, 255, 242), outline=(255, 255, 255, 34), width=2)

    inset = 30
    screen_box = (
        card_box[0] + inset,
        card_box[1] + inset,
        card_box[2] - inset,
        card_box[3] - inset,
    )
    draw.rounded_rectangle(screen_box, radius=58, fill=(5, 6, 10))

    source = Image.open(source_path).convert("RGBA")
    target_size = (screen_box[2] - screen_box[0], screen_box[3] - screen_box[1])
    source = fit_source(source, target_size)
    screen_mask = Image.new("L", (screen_box[2] - screen_box[0], screen_box[3] - screen_box[1]), 0)
    mask_draw = ImageDraw.Draw(screen_mask)
    mask_draw.rounded_rectangle((0, 0, screen_mask.width, screen_mask.height), radius=50, fill=255)

    content = Image.new("RGBA", base.size, (0, 0, 0, 0))
    content.paste(source, (screen_box[0], screen_box[1]), screen_mask)
    card_layer.alpha_composite(content)

    reflection = Image.new("RGBA", base.size, (0, 0, 0, 0))
    reflection_draw = ImageDraw.Draw(reflection)
    reflection_draw.polygon(
        [
            (screen_box[0] + 80, screen_box[1] + 50),
            (screen_box[0] + 280, screen_box[1] + 24),
            (screen_box[2] - 50, screen_box[3] - 520),
            (screen_box[2] - 6, screen_box[3] - 350),
        ],
        fill=(255, 255, 255, 16),
    )
    reflection = reflection.filter(ImageFilter.GaussianBlur(26))
    card_layer.alpha_composite(reflection)

    base.alpha_composite(card_layer)


def build_screen(spec):
    image = make_background(spec["accent"])
    draw = ImageDraw.Draw(image)
    draw_eyebrow(draw, spec["eyebrow"], spec["accent"])
    draw_headline(draw, spec["headline"])
    add_screen_card(image, SOURCE_DIR / spec["source"])
    return image.convert("RGB")


def build_preview(output_paths):
    card_w = 480
    card_h = 1040
    gap = 32
    left = 36
    top = 46
    board_width = left * 2 + card_w * len(output_paths) + gap * (len(output_paths) - 1)
    board = Image.new("RGB", (board_width, 1220), (243, 242, 246))
    x = left
    y = top
    for output in output_paths:
        shadow = Image.new("RGBA", board.size, (0, 0, 0, 0))
        shadow_draw = ImageDraw.Draw(shadow)
        shadow_draw.rounded_rectangle((x + 8, y + 18, x + card_w + 8, y + card_h + 18), radius=40, fill=(0, 0, 0, 26))
        shadow = shadow.filter(ImageFilter.GaussianBlur(18))
        board = Image.alpha_composite(board.convert("RGBA"), shadow).convert("RGB")

        image = Image.open(output).convert("RGB")
        image = image.resize((card_w, card_h), Image.Resampling.LANCZOS)
        mask = Image.new("L", (card_w, card_h), 0)
        mask_draw = ImageDraw.Draw(mask)
        mask_draw.rounded_rectangle((0, 0, card_w, card_h), radius=40, fill=255)
        board.paste(image, (x, y), mask)
        x += card_w + gap
    return board


def main():
    OUTDIR.mkdir(parents=True, exist_ok=True)
    outputs = []
    for spec in SCREENS:
        output = OUTDIR / spec["filename"]
        build_screen(spec).save(output, quality=95)
        outputs.append(output)

    build_preview(outputs).save(OUTDIR / "preview-board.png", quality=95)


if __name__ == "__main__":
    main()
