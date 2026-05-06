#!/usr/bin/env python3

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import numpy as np


ROOT = Path("/Users/castao/Desktop/PetMed/TailyDose")
SOURCE_DIR = ROOT / "mockups" / "simulator-screenshots"
OUTDIR = ROOT / "mockups" / "marketing-3d"
SIZE = (1284, 2778)
FONT_PATH = "/System/Library/Fonts/Helvetica.ttc"


SCREENS = [
    {
        "filename": "01-home-3d-marketing.png",
        "source": "01-home-actual.png",
        "badge": "SEE TODAY CLEARLY",
        "headline": "Every pet.\nEvery dose.\nOne calm home.",
        "accent": (178, 150, 242),
        "yaw": -5,
        "pitch": 1,
        "roll": -4,
        "phone_scale": 1.0,
        "phone_center": (660, 2085),
        "overlay": {
            "title": "UP NEXT",
            "lines": ["Olive • Carprofen at 6:30 PM"],
        },
    },
    {
        "filename": "02-manage-3d-marketing.png",
        "source": "02-manage-actual.png",
        "badge": "KEEP IT ORGANIZED",
        "headline": "Profiles, meds,\nand reminders\nkept in sync.",
        "accent": (196, 212, 118),
        "yaw": 6,
        "pitch": 1,
        "roll": 4,
        "phone_scale": 0.96,
        "phone_center": (670, 2095),
        "overlay": {
            "title": "MULTI-PET READY",
            "lines": ["3 pets • 6 active meds"],
        },
    },
    {
        "filename": "03-history-3d-marketing.png",
        "source": "03-history-actual.png",
        "badge": "STAY AHEAD",
        "headline": "Taken, missed,\nor skipped.\nAlways clear.",
        "accent": (246, 182, 103),
        "yaw": -6,
        "pitch": 1,
        "roll": -4,
        "phone_scale": 0.98,
        "phone_center": (660, 2095),
        "overlay": {
            "title": "HISTORY",
            "lines": ["Daily adherence stays readable"],
        },
    },
    {
        "filename": "04-lockscreen-3d-marketing.png",
        "source": "07-lockscreen-notification-bright.png",
        "badge": "NEVER MISS A DOSE",
        "headline": "Lock screen alerts\nwhen the next dose\nis due.",
        "accent": (242, 149, 186),
        "yaw": 0,
        "pitch": 0,
        "roll": 0,
        "phone_scale": 1.02,
        "phone_center": (660, 2095),
        "overlay": {
            "title": "LOCK SCREEN",
            "lines": ["Fresh reminders, right on time"],
        },
    },
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    font_index = 1 if bold else 0
    return ImageFont.truetype(FONT_PATH, size=size, index=font_index)


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


def make_background(accent):
    image = Image.new("RGBA", SIZE, (0, 0, 0, 255))
    pixels = image.load()
    top = (13, 14, 32)
    bottom = (30, 18, 55)
    for y in range(SIZE[1]):
        ratio = y / (SIZE[1] - 1)
        row = tuple(int(top[i] * (1 - ratio) + bottom[i] * ratio) for i in range(3))
        for x in range(SIZE[0]):
            pixels[x, y] = row + (255,)

    glow = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    draw.ellipse((730, 90, 1230, 640), fill=accent + (50,))
    draw.ellipse((70, 1880, 540, 2380), fill=(255, 255, 255, 24))
    draw.ellipse((880, 1710, 1240, 2360), fill=accent + (24,))
    glow = glow.filter(ImageFilter.GaussianBlur(70))
    image.alpha_composite(glow)

    grid = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    grid_draw = ImageDraw.Draw(grid)
    for offset in range(-SIZE[1], SIZE[0], 140):
        grid_draw.line((offset, 0, offset + SIZE[1], SIZE[1]), fill=(255, 255, 255, 8), width=1)
    grid = grid.filter(ImageFilter.GaussianBlur(1))
    image.alpha_composite(grid)
    return image


def draw_badge(draw, text, accent):
    badge_font = font(28, bold=True)
    width, height = text_size(draw, text, badge_font)
    box = (SIZE[0] // 2 - width // 2 - 34, 154, SIZE[0] // 2 + width // 2 + 34, 154 + height + 18)
    draw.rounded_rectangle(box, radius=24, fill=accent + (44,), outline=accent + (92,), width=2)
    draw.text((box[0] + 34, box[1] + 8), text, font=badge_font, fill=(245, 242, 248))


def draw_centered_headline(draw, text):
    headline_font = font(68)
    lines = wrap_text(draw, text, headline_font, SIZE[0] - 220)
    metrics = [(*text_size(draw, line, headline_font), line) for line in lines]
    total_height = sum(height for _, height, _ in metrics) + max(0, len(metrics) - 1) * 10
    y = 336
    for width, height, line in metrics:
        x = (SIZE[0] - width) / 2
        draw.text((x, y), line, font=headline_font, fill=(247, 244, 250))
        y += height + 10


def rounded_shadow(base, box, radius, shadow_color, blur_radius, offset):
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shifted = (box[0] + offset[0], box[1] + offset[1], box[2] + offset[0], box[3] + offset[1])
    shadow_draw.rounded_rectangle(shifted, radius=radius, fill=shadow_color)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur_radius))
    base.alpha_composite(shadow)


def vertical_gradient(size, top_color, bottom_color):
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    for y in range(size[1]):
        ratio = y / max(1, size[1] - 1)
        color = tuple(int(top_color[i] * (1 - ratio) + bottom_color[i] * ratio) for i in range(4))
        draw.line((0, y, size[0], y), fill=color)
    return image


def fit_image(source: Image.Image, size):
    target_ratio = size[0] / size[1]
    source_ratio = source.width / source.height
    if source_ratio > target_ratio:
        new_height = source.height
        new_width = int(new_height * target_ratio)
        left = (source.width - new_width) // 2
        crop = source.crop((left, 0, left + new_width, new_height))
    else:
        new_width = source.width
        new_height = int(new_width / target_ratio)
        top = (source.height - new_height) // 2
        crop = source.crop((0, top, new_width, top + new_height))
    return crop.resize(size, Image.Resampling.LANCZOS)


def build_phone_face(source_path: Path, scale: float):
    face_size = (920, 1880)
    shell = Image.new("RGBA", face_size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(shell)

    body_box = (44, 20, face_size[0] - 44, face_size[1] - 20)
    metal = vertical_gradient(face_size, (68, 72, 84, 255), (22, 24, 30, 255))
    metal_mask = Image.new("L", face_size, 0)
    mask_draw = ImageDraw.Draw(metal_mask)
    mask_draw.rounded_rectangle(body_box, radius=118, fill=255)
    shell.paste(metal, (0, 0), metal_mask)

    frame_highlight = Image.new("RGBA", face_size, (0, 0, 0, 0))
    highlight_draw = ImageDraw.Draw(frame_highlight)
    highlight_draw.rounded_rectangle(body_box, radius=118, outline=(255, 255, 255, 185), width=4)
    highlight_draw.rounded_rectangle((56, 34, face_size[0] - 56, face_size[1] - 34), radius=108, outline=(255, 255, 255, 32), width=2)
    frame_highlight = frame_highlight.filter(ImageFilter.GaussianBlur(0.5))
    shell.alpha_composite(frame_highlight)

    screen_box = (92, 90, face_size[0] - 92, face_size[1] - 90)
    draw.rounded_rectangle(screen_box, radius=88, fill=(4, 5, 8))

    source = Image.open(source_path).convert("RGBA")
    fitted = fit_image(source, (screen_box[2] - screen_box[0], screen_box[3] - screen_box[1]))
    mask = Image.new("L", fitted.size, 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle((0, 0, fitted.size[0], fitted.size[1]), radius=76, fill=255)
    screen_image = Image.new("RGBA", face_size, (0, 0, 0, 0))
    screen_image.paste(fitted, (screen_box[0], screen_box[1]), mask)
    shell.alpha_composite(screen_image)

    island = (face_size[0] // 2 - 116, 126, face_size[0] // 2 + 116, 192)
    draw.rounded_rectangle(island, radius=38, fill=(1, 1, 2))
    draw.ellipse((island[0] + 34, island[1] + 20, island[0] + 66, island[1] + 52), fill=(11, 13, 18))
    draw.ellipse((island[2] - 66, island[1] + 20, island[2] - 34, island[1] + 52), fill=(11, 13, 18))

    reflection = Image.new("RGBA", face_size, (0, 0, 0, 0))
    reflection_draw = ImageDraw.Draw(reflection)
    reflection_draw.polygon(
        [
            (screen_box[0] + 110, screen_box[1] + 36),
            (screen_box[0] + 250, screen_box[1] + 18),
            (screen_box[2] - 100, screen_box[3] - 520),
            (screen_box[2] - 20, screen_box[3] - 330),
        ],
        fill=(255, 255, 255, 18),
    )
    reflection = reflection.filter(ImageFilter.GaussianBlur(34))
    shell.alpha_composite(reflection)

    if scale != 1.0:
        shell = shell.resize(
            (int(shell.width * scale), int(shell.height * scale)),
            Image.Resampling.LANCZOS,
        )

    return shell


def rotate_point(x, y, z, yaw, pitch, roll):
    yaw_r = np.radians(yaw)
    pitch_r = np.radians(pitch)
    roll_r = np.radians(roll)

    cos_y, sin_y = np.cos(yaw_r), np.sin(yaw_r)
    cos_p, sin_p = np.cos(pitch_r), np.sin(pitch_r)
    cos_r, sin_r = np.cos(roll_r), np.sin(roll_r)

    x1 = x * cos_y + z * sin_y
    z1 = -x * sin_y + z * cos_y

    y2 = y * cos_p - z1 * sin_p
    z2 = y * sin_p + z1 * cos_p

    x3 = x1 * cos_r - y2 * sin_r
    y3 = x1 * sin_r + y2 * cos_r
    return x3, y3, z2


def project_phone_quad(center, face_size, yaw, pitch, roll, depth=14, perspective=5200):
    width, height = face_size
    corners = [
        (-width / 2, -height / 2, 0),
        (width / 2, -height / 2, 0),
        (width / 2, height / 2, 0),
        (-width / 2, height / 2, 0),
    ]

    front = []
    back = []
    for x, y, z in corners:
        fx, fy, fz = rotate_point(x, y, z, yaw, pitch, roll)
        bx, by, bz = rotate_point(x, y, z - depth, yaw, pitch, roll)

        f_scale = perspective / (perspective - fz)
        b_scale = perspective / (perspective - bz)

        front.append((center[0] + fx * f_scale, center[1] + fy * f_scale))
        back.append((center[0] + bx * b_scale, center[1] + by * b_scale))

    return front, back


def find_perspective_coeffs(src_pts, dst_pts):
    matrix = []
    for (sx, sy), (dx, dy) in zip(src_pts, dst_pts):
        matrix.append([dx, dy, 1, 0, 0, 0, -sx * dx, -sx * dy])
        matrix.append([0, 0, 0, dx, dy, 1, -sy * dx, -sy * dy])
    a = np.array(matrix, dtype=float)
    b = np.array(src_pts).reshape(8)
    coeffs = np.linalg.solve(a, b)
    return coeffs


def warp_image_to_quad(image: Image.Image, quad):
    min_x = int(min(x for x, _ in quad))
    min_y = int(min(y for _, y in quad))
    max_x = int(max(x for x, _ in quad))
    max_y = int(max(y for _, y in quad))
    width = max_x - min_x
    height = max_y - min_y
    shifted_quad = [(x - min_x, y - min_y) for x, y in quad]
    src_rect = [(0, 0), (image.width, 0), (image.width, image.height), (0, image.height)]
    coeffs = find_perspective_coeffs(src_rect, shifted_quad)
    warped = image.transform(
        (width, height),
        Image.Transform.PERSPECTIVE,
        coeffs,
        resample=Image.Resampling.BICUBIC,
    )
    return warped, (min_x, min_y)


def blend_color(a, b, ratio):
    return tuple(int(a[i] * (1 - ratio) + b[i] * ratio) for i in range(4))


def draw_side_polygon(base, front_a, front_b, back_b, back_a, lightness):
    poly = [front_a, front_b, back_b, back_a]
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    fill = blend_color((28, 30, 38, 255), (138, 146, 164, 255), lightness)
    draw.polygon(poly, fill=fill)
    outline = blend_color((255, 255, 255, 18), (255, 255, 255, 62), lightness)
    draw.line([front_a, back_a], fill=outline, width=1)
    draw.line([front_b, back_b], fill=outline, width=1)
    overlay = overlay.filter(ImageFilter.GaussianBlur(0.25))
    base.alpha_composite(overlay)


def draw_side_buttons(base, quad, yaw):
    if abs(yaw) < 2:
        return
    left_edge_top, left_edge_bottom = quad[0], quad[3]
    right_edge_top, right_edge_bottom = quad[1], quad[2]
    edge_top, edge_bottom = (right_edge_top, right_edge_bottom) if yaw > 0 else (left_edge_top, left_edge_bottom)

    def point_at(t, outward=0):
        x = edge_top[0] + (edge_bottom[0] - edge_top[0]) * t
        y = edge_top[1] + (edge_bottom[1] - edge_top[1]) * t
        nx = edge_bottom[1] - edge_top[1]
        ny = -(edge_bottom[0] - edge_top[0])
        length = max((nx ** 2 + ny ** 2) ** 0.5, 1)
        nx /= length
        ny /= length
        return x + nx * outward, y + ny * outward

    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for start_t, end_t in [(0.24, 0.34), (0.44, 0.54)]:
        a = point_at(start_t, 5)
        b = point_at(end_t, 5)
        draw.line([a, b], fill=(186, 192, 202, 110), width=5)
    overlay = overlay.filter(ImageFilter.GaussianBlur(0.8))
    base.alpha_composite(overlay)


def make_phone_mockup(source_path: Path, center, yaw, pitch, roll, scale):
    face = build_phone_face(source_path, scale)
    front_quad, back_quad = project_phone_quad(center, face.size, yaw, pitch, roll)

    canvas = Image.new("RGBA", SIZE, (0, 0, 0, 0))

    shadow = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_poly = [(x + 16, y + 18) for x, y in front_quad]
    shadow_draw.polygon(shadow_poly, fill=(0, 0, 0, 100))
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    canvas.alpha_composite(shadow)

    if yaw < -1:
        draw_side_polygon(canvas, front_quad[1], front_quad[2], back_quad[2], back_quad[1], 0.34)
    elif yaw > 1:
        draw_side_polygon(canvas, front_quad[3], front_quad[0], back_quad[0], back_quad[3], 0.20)
    if pitch > 0.5:
        draw_side_polygon(canvas, front_quad[2], front_quad[3], back_quad[3], back_quad[2], 0.08)

    front_warp, front_pos = warp_image_to_quad(face, front_quad)
    canvas.alpha_composite(front_warp, dest=front_pos)
    draw_side_buttons(canvas, front_quad, yaw)

    return canvas, front_quad


def draw_overlay_card(base, accent, center_x, top_y, overlay):
    if not overlay:
        return
    width = 640
    height = 132
    box = (center_x - width // 2, top_y, center_x + width // 2, top_y + height)
    rounded_shadow(base, box, 28, (0, 0, 0, 90), 16, (0, 12))

    card = Image.new("RGBA", base.size, (0, 0, 0, 0))
    card_draw = ImageDraw.Draw(card)
    card_draw.rounded_rectangle(box, radius=28, fill=(62, 66, 92, 188), outline=(255, 255, 255, 20), width=1)
    badge_font = font(23, bold=True)
    line_font = font(22)
    card_draw.text((box[0] + 30, box[1] + 22), overlay["title"], font=badge_font, fill=accent + (255,))
    y = box[1] + 58
    for line in overlay["lines"]:
        card_draw.text((box[0] + 30, y), line, font=line_font, fill=(236, 239, 246))
        y += 30
    card.alpha_composite(Image.new("RGBA", base.size, (0, 0, 0, 0)))
    base.alpha_composite(card)


def build_marketing_image(spec):
    image = make_background(spec["accent"])
    draw = ImageDraw.Draw(image)
    draw_badge(draw, spec["badge"], spec["accent"])
    draw_centered_headline(draw, spec["headline"])

    phone, front_quad = make_phone_mockup(
        SOURCE_DIR / spec["source"],
        spec["phone_center"],
        spec["yaw"],
        spec["pitch"],
        spec["roll"],
        spec["phone_scale"],
    )
    image.alpha_composite(phone)
    draw_overlay_card(
        image,
        spec["accent"],
        int(spec["phone_center"][0]),
        max(970, int(min(y for _, y in front_quad)) - 86),
        spec.get("overlay"),
    )
    return image.convert("RGB")


def build_preview_board(marketing_files):
    board_size = (2200, 1180)
    board = Image.new("RGB", board_size, (245, 244, 247))
    draw = ImageDraw.Draw(board)

    card_width = 500
    gap = 36
    left = 40
    top = 40
    radius = 42

    for index, file_path in enumerate(marketing_files):
        x = left + index * (card_width + gap)
        y = top
        card_box = (x, y, x + card_width, y + 1100)

        shadow = Image.new("RGBA", board.size, (0, 0, 0, 0))
        shadow_draw = ImageDraw.Draw(shadow)
        shadow_draw.rounded_rectangle(
            (card_box[0] + 8, card_box[1] + 18, card_box[2] + 8, card_box[3] + 18),
            radius=radius,
            fill=(0, 0, 0, 28),
        )
        shadow = shadow.filter(ImageFilter.GaussianBlur(20))
        board = Image.alpha_composite(board.convert("RGBA"), shadow).convert("RGB")

        image = Image.open(file_path).convert("RGB")
        image = fit_image(image, (card_width, 1100))
        mask = Image.new("L", (card_width, 1100), 0)
        mask_draw = ImageDraw.Draw(mask)
        mask_draw.rounded_rectangle((0, 0, card_width, 1100), radius=radius, fill=255)
        board.paste(image, (x, y), mask)

    return board


def main():
    OUTDIR.mkdir(parents=True, exist_ok=True)
    marketing_files = []
    for spec in SCREENS:
        output_path = OUTDIR / spec["filename"]
        build_marketing_image(spec).save(output_path, quality=95)
        marketing_files.append(output_path)

    preview = build_preview_board(marketing_files)
    preview.save(OUTDIR / "preview-board.png", quality=95)


if __name__ == "__main__":
    main()
