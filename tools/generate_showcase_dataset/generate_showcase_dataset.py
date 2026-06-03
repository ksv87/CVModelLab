#!/usr/bin/env python3
"""
Synthetic showcase dataset generator for CV Model Lab.

Generates 40 synthetic road-scene images plus COCO-compatible annotations,
predictions for three model variants, and precomputed AP metrics JSONs.

Requirements: Python 3.8+, Pillow (pip install Pillow)
Run from repository root:
    python3 tools/generate_showcase_dataset/generate_showcase_dataset.py
"""
from __future__ import annotations

import json
import math
import os
import random
from pathlib import Path
from typing import List, Tuple, Dict, Any, Optional

try:
    from PIL import Image, ImageDraw
except ImportError:
    raise SystemExit("Pillow is required: pip install Pillow")

# ── Configuration ─────────────────────────────────────────────────────────────

SEED = 42
IMG_W, IMG_H = 960, 540
OUT_DIR = Path(__file__).parent.parent.parent / "demo" / "showcase_coco"
IMAGES_DIR = OUT_DIR / "images"

CATEGORIES = [
    {"id": 1, "name": "red_light",           "supercategory": "traffic_light"},
    {"id": 2, "name": "yellow_light",         "supercategory": "traffic_light"},
    {"id": 3, "name": "green_light",          "supercategory": "traffic_light"},
    {"id": 4, "name": "pedestrian_sign",      "supercategory": "sign"},
    {"id": 5, "name": "background_distractor","supercategory": "other"},
]
CAT_BY_NAME = {c["name"]: c["id"] for c in CATEGORIES}

# ── Scene constants ───────────────────────────────────────────────────────────

HORIZON_FRAC = 0.42          # sky/ground split
HORIZON_Y   = int(IMG_H * HORIZON_FRAC)

# Palette
SKY_TOP     = (95, 140, 220)
SKY_BOT     = (175, 205, 235)
GROUND      = (72, 72, 76)
ROAD_MARK_Y = (220, 195, 50)
ROAD_MARK_W = (230, 230, 230)
POLE_C      = (38, 38, 38)
HOUSE_C     = (28, 28, 28)
SIGN_BG_C   = (25, 55, 175)
SIGN_FG_C   = (255, 255, 255)
LAMP_C      = (200, 178, 105)
FLARE_C     = (255, 255, 200)

# ── Drawing helpers ───────────────────────────────────────────────────────────

def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def lerp_color(c1: tuple, c2: tuple, t: float) -> tuple:
    return tuple(int(lerp(a, b, t)) for a, b in zip(c1, c2))


def draw_sky(draw: ImageDraw.ImageDraw) -> None:
    for y in range(HORIZON_Y):
        t = y / max(1, HORIZON_Y - 1)
        draw.line([(0, y), (IMG_W - 1, y)], fill=lerp_color(SKY_TOP, SKY_BOT, t))


def draw_ground(draw: ImageDraw.ImageDraw, rng: random.Random) -> None:
    shade_var = rng.randint(-8, 8)
    g = tuple(max(0, min(255, GROUND[i] + shade_var)) for i in range(3))
    draw.rectangle([0, HORIZON_Y, IMG_W, IMG_H], fill=g)
    # Sidewalk strip
    sw_y = HORIZON_Y + rng.randint(30, 55)
    draw.rectangle([0, HORIZON_Y, IMG_W, sw_y], fill=(100, 100, 102))
    # Road markings (two lanes)
    for x in range(0, IMG_W, 65):
        draw.rectangle([x, sw_y + 45, x + 38, sw_y + 52], fill=ROAD_MARK_W)
    for x in range(0, IMG_W, 65):
        draw.rectangle([x, IMG_H - 50, x + 38, IMG_H - 44], fill=ROAD_MARK_Y)


def draw_buildings(draw: ImageDraw.ImageDraw, rng: random.Random, n: int = 4) -> None:
    xs = sorted(rng.sample(range(20, IMG_W - 80), min(n, IMG_W // 80)))
    for bx in xs:
        bw  = rng.randint(55, 130)
        bh  = rng.randint(60, 160)
        by  = HORIZON_Y - bh
        shade = rng.randint(48, 78)
        draw.rectangle([bx, by, bx + bw, HORIZON_Y], fill=(shade, shade, shade + 4))
        # Windows
        for wy in range(by + 8, HORIZON_Y - 8, 20):
            for wx in range(bx + 6, bx + bw - 6, 17):
                lit   = rng.random() > 0.35
                wcol  = (195, 185, 115) if lit else (25, 35, 45)
                draw.rectangle([wx, wy, wx + 10, wy + 12], fill=wcol)


def draw_traffic_light(
    draw: ImageDraw.ImageDraw,
    cx: int, cy: int,
    size: int,
    active: int,           # 0=red 1=yellow 2=green
) -> Tuple[List[int], List[List[int]]]:
    """Return (housing_bbox, [per_light_bbox × 3])  — all [x,y,w,h]."""
    pad  = max(4, size // 3)
    gap  = max(2, size // 5)
    hw   = size + pad * 2
    hh   = size * 3 + gap * 2 + pad * 2
    hx   = cx - hw // 2
    hy   = cy - hh // 2

    # Pole
    pw       = max(4, size // 6)
    pole_top = cy + hh // 2
    pole_bot = max(pole_top + 1, HORIZON_Y + 25)
    draw.rectangle([cx - pw // 2, pole_top, cx + pw // 2, pole_bot], fill=POLE_C)
    # Housing
    draw.rounded_rectangle([hx, hy, hx + hw, hy + hh], radius=size // 3, fill=HOUSE_C)

    dim   = [(190, 38, 38), (185, 155, 38), (38, 168, 38)]
    bright= [(255, 65, 65), (255, 225, 65), (85, 255, 85)]

    light_bboxes: List[List[int]] = []
    for i in range(3):
        lx = cx
        ly = hy + pad + size // 2 + i * (size + gap)
        col = bright[i] if i == active else dim[i]
        r   = size // 2
        draw.ellipse([lx - r, ly - r, lx + r, ly + r], fill=col)
        if i == active:
            # subtle glow ring
            for g in range(4, 0, -1):
                draw.ellipse(
                    [lx - r - g * 2, ly - r - g * 2, lx + r + g * 2, ly + r + g * 2],
                    fill=col[:3] + (20,),
                )
        light_bboxes.append([lx - r, ly - r, size, size])

    housing_bbox = [hx, hy, hw, hh]
    return housing_bbox, light_bboxes


def draw_pedestrian_sign(
    draw: ImageDraw.ImageDraw,
    cx: int, cy: int,
    w: int, h: int,
) -> List[int]:
    """Draw a pedestrian crossing sign; return [x,y,w,h]."""
    x, y = cx - w // 2, cy - h // 2
    draw.rectangle([cx - 3, cy + h // 2, cx + 3, HORIZON_Y + 15], fill=POLE_C)
    draw.rectangle([x, y, x + w, y + h], fill=SIGN_BG_C)
    draw.rectangle([x + 2, y + 2, x + w - 2, y + h - 2], outline=SIGN_FG_C, width=2)
    hr = max(5, w // 9)
    hx2, hy2 = cx, y + h // 5
    draw.ellipse([hx2 - hr, hy2 - hr, hx2 + hr, hy2 + hr], fill=SIGN_FG_C)
    draw.line([hx2, hy2 + hr, hx2, y + h - h // 5], fill=SIGN_FG_C, width=3)
    draw.line([hx2, y + h * 2 // 5, hx2 - w // 6, y + h // 2 + h // 7],
              fill=SIGN_FG_C, width=2)
    draw.line([hx2, y + h * 2 // 5, hx2 + w // 6, y + h // 2 + h // 7],
              fill=SIGN_FG_C, width=2)
    return [x, y, w, h]


def draw_street_lamp(
    draw: ImageDraw.ImageDraw,
    cx: int, base_y: int,
    height: int, lamp_r: int,
) -> List[int]:
    """Street lamp (background distractor). Return [x,y,w,h] of lamp head."""
    draw.rectangle([cx - 3, base_y - height, cx + 3, base_y], fill=POLE_C)
    arm_ex = cx + lamp_r
    arm_ey = base_y - height + lamp_r // 2
    draw.line([cx, base_y - height, arm_ex, arm_ey], fill=POLE_C, width=4)
    draw.ellipse([arm_ex - lamp_r, arm_ey - lamp_r // 2,
                  arm_ex + lamp_r, arm_ey + lamp_r // 2], fill=LAMP_C)
    return [arm_ex - lamp_r, arm_ey - lamp_r // 2, lamp_r * 2, lamp_r]


def draw_flare(draw: ImageDraw.ImageDraw, cx: int, cy: int, r: int) -> List[int]:
    """Small lens-flare blob (triggers FP on distractor-sensitive models)."""
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=FLARE_C + (160,))
    return [cx - r, cy - r, r * 2, r * 2]

# ── Scene builders ────────────────────────────────────────────────────────────

def base_scene(rng: random.Random, n_buildings: int = 4):
    img  = Image.new("RGB", (IMG_W, IMG_H))
    draw = ImageDraw.Draw(img, "RGBA")
    draw_sky(draw)
    draw_ground(draw, rng)
    draw_buildings(draw, rng, n=n_buildings)
    return img, ImageDraw.Draw(img, "RGBA")


def scene_single_light(rng: random.Random, cat_name: str, size: int = 60):
    """Clear single traffic light — easy TP."""
    img, draw = base_scene(rng)
    cx = rng.randint(IMG_W // 3, 2 * IMG_W // 3)
    cy = HORIZON_Y - size - rng.randint(20, 60)
    active = ["red_light", "yellow_light", "green_light"].index(cat_name)
    hbbox, _ = draw_traffic_light(draw, cx, cy, size, active)
    return img, [{"cat": cat_name, "bbox": hbbox}]


def scene_two_lights(rng: random.Random, cat_a: str, cat_b: str, size: int = 50):
    """Two traffic lights side by side."""
    img, draw = base_scene(rng)
    cx_a = rng.randint(IMG_W // 5, IMG_W // 2 - 50)
    cx_b = rng.randint(IMG_W // 2 + 50, 4 * IMG_W // 5)
    cy   = HORIZON_Y - size - rng.randint(15, 50)
    act_a = ["red_light", "yellow_light", "green_light"].index(cat_a)
    act_b = ["red_light", "yellow_light", "green_light"].index(cat_b)
    hb_a, _ = draw_traffic_light(draw, cx_a, cy, size, act_a)
    hb_b, _ = draw_traffic_light(draw, cx_b, cy, size, act_b)
    return img, [
        {"cat": cat_a, "bbox": hb_a},
        {"cat": cat_b, "bbox": hb_b},
    ]


def scene_light_and_sign(rng: random.Random, light_cat: str, size: int = 50):
    """Traffic light + pedestrian sign."""
    img, draw = base_scene(rng)
    cx_l = rng.randint(IMG_W // 4, IMG_W // 2)
    cx_s = rng.randint(IMG_W // 2 + 40, 3 * IMG_W // 4)
    cy   = HORIZON_Y - size - rng.randint(20, 45)
    active = ["red_light", "yellow_light", "green_light"].index(light_cat)
    hb, _ = draw_traffic_light(draw, cx_l, cy, size, active)
    sw, sh = rng.randint(35, 55), rng.randint(50, 70)
    sbbox  = draw_pedestrian_sign(draw, cx_s, cy, sw, sh)
    return img, [
        {"cat": light_cat, "bbox": hb},
        {"cat": "pedestrian_sign", "bbox": sbbox},
    ]


def scene_distractors(rng: random.Random, n_lamps: int = 3, n_lights: int = 1):
    """Street lamps (background_distractor) with optional real traffic lights."""
    img, draw = base_scene(rng, n_buildings=rng.randint(3, 6))
    annotations = []
    positions = sorted(rng.sample(range(60, IMG_W - 60), n_lamps + n_lights))
    lamp_positions = positions[:n_lamps]
    light_positions = positions[n_lamps:]

    for cx in lamp_positions:
        h = rng.randint(100, 160)
        lr = rng.randint(14, 22)
        bbox = draw_street_lamp(draw, cx, HORIZON_Y + rng.randint(10, 25), h, lr)
        annotations.append({"cat": "background_distractor", "bbox": bbox})

    for cx in light_positions:
        size = rng.randint(35, 55)
        cy   = HORIZON_Y - size - rng.randint(15, 40)
        cat  = rng.choice(["red_light", "green_light"])
        active = ["red_light", "yellow_light", "green_light"].index(cat)
        hb, _ = draw_traffic_light(draw, cx, cy, size, active)
        annotations.append({"cat": cat, "bbox": hb})

    return img, annotations


def scene_small_objects(rng: random.Random, n: int = 3):
    """Distant small traffic lights (area < 1024 px²)."""
    img, draw = base_scene(rng, n_buildings=rng.randint(3, 5))
    annotations = []
    # Large foreground distractor to make scene look realistic
    if rng.random() > 0.4:
        hb, _ = draw_traffic_light(draw, IMG_W // 2, HORIZON_Y - 70, 50, rng.randint(0, 2))
        annotations.append({"cat": rng.choice(["red_light", "green_light"]), "bbox": hb})

    xs = sorted(rng.sample(range(50, IMG_W - 50), n))
    for cx in xs:
        size = rng.randint(12, 22)   # small — area ~ 200–900 px²
        cy   = HORIZON_Y - rng.randint(5, 20)
        cat  = rng.choice(["red_light", "yellow_light", "green_light"])
        active = ["red_light", "yellow_light", "green_light"].index(cat)
        hb, _ = draw_traffic_light(draw, cx, cy, size, active)
        annotations.append({"cat": cat, "bbox": hb})

    return img, annotations


def scene_background_only(rng: random.Random):
    """No GT annotations — pure background (FP testing)."""
    img, draw = base_scene(rng, n_buildings=rng.randint(2, 5))
    # Add flares that tempt models into FP
    for _ in range(rng.randint(1, 3)):
        cx = rng.randint(100, IMG_W - 100)
        cy = rng.randint(HORIZON_Y - 120, HORIZON_Y - 20)
        draw_flare(draw, cx, cy, rng.randint(6, 14))
    return img, []


def scene_no_predictions(rng: random.Random):
    """GT exists but all models miss (night/obscured conditions)."""
    img, draw = base_scene(rng, n_buildings=rng.randint(3, 5))
    # Dark overlay to simulate low visibility
    dark = Image.new("RGBA", (IMG_W, IMG_H), (0, 0, 0, 120))
    img.paste(dark, mask=dark)
    draw = ImageDraw.Draw(img, "RGBA")
    annotations = []
    for _ in range(rng.randint(1, 2)):
        cx   = rng.randint(200, IMG_W - 200)
        size = rng.randint(35, 55)
        cy   = HORIZON_Y - size - rng.randint(20, 50)
        cat  = rng.choice(["red_light", "green_light"])
        active = ["red_light", "yellow_light", "green_light"].index(cat)
        hb, _ = draw_traffic_light(draw, cx, cy, size, active)
        annotations.append({"cat": cat, "bbox": hb})
    return img, annotations


def scene_complex(rng: random.Random):
    """Multi-object scene: 2 lights + sign + distractor."""
    img, draw = base_scene(rng, n_buildings=rng.randint(3, 6))
    annotations = []
    size_l = rng.randint(40, 60)
    cy     = HORIZON_Y - size_l - rng.randint(20, 45)

    for cx, cat_name in [(IMG_W // 4, "red_light"), (3 * IMG_W // 4, "green_light")]:
        active = ["red_light", "yellow_light", "green_light"].index(cat_name)
        hb, _ = draw_traffic_light(draw, cx, cy, size_l, active)
        annotations.append({"cat": cat_name, "bbox": hb})

    # Pedestrian sign
    sw, sh = rng.randint(38, 52), rng.randint(52, 68)
    sbbox  = draw_pedestrian_sign(draw, IMG_W // 2, cy, sw, sh)
    annotations.append({"cat": "pedestrian_sign", "bbox": sbbox})

    # Street lamp (distractor)
    lr = rng.randint(14, 20)
    bbox = draw_street_lamp(draw, rng.randint(700, 850), HORIZON_Y + 15, 120, lr)
    annotations.append({"cat": "background_distractor", "bbox": bbox})

    return img, annotations

# ── Scene schedule (40 images) ────────────────────────────────────────────────

def build_scenes(rng: random.Random):
    """Return list of (img, annotations) pairs — 40 entries."""
    scenes = []

    # 1-5: single clear traffic lights (easy TP for all models)
    for cat in ["red_light", "green_light", "green_light", "red_light", "yellow_light"]:
        scenes.append(scene_single_light(rng, cat, size=rng.randint(55, 75)))

    # 6-10: two traffic lights
    for a, b in [("red_light", "green_light"), ("green_light", "red_light"),
                 ("yellow_light", "red_light"), ("green_light", "yellow_light"),
                 ("red_light", "red_light")]:
        scenes.append(scene_two_lights(rng, a, b, size=rng.randint(44, 58)))

    # 11-15: light + pedestrian sign (class confusion opportunity)
    for cat in ["green_light", "red_light", "yellow_light", "green_light", "red_light"]:
        scenes.append(scene_light_and_sign(rng, cat, size=rng.randint(40, 55)))

    # 16-22: background distractors
    for _ in range(4):
        scenes.append(scene_distractors(rng, n_lamps=rng.randint(2, 4), n_lights=0))
    for _ in range(3):
        scenes.append(scene_distractors(rng, n_lamps=rng.randint(2, 3), n_lights=1))

    # 23-28: small objects
    for _ in range(6):
        scenes.append(scene_small_objects(rng, n=rng.randint(2, 4)))

    # 29-33: background-only (no GT)
    for _ in range(5):
        scenes.append(scene_background_only(rng))

    # 34-37: GT but no predictions (obscured/dark)
    for _ in range(4):
        scenes.append(scene_no_predictions(rng))

    # 38-40: complex mixed scenes
    for _ in range(3):
        scenes.append(scene_complex(rng))

    return scenes

# ── Annotation builder ────────────────────────────────────────────────────────

def clip_bbox(bbox: List[int]) -> List[int]:
    x, y, w, h = bbox
    x = max(0, min(IMG_W - 1, x))
    y = max(0, min(IMG_H - 1, y))
    w = max(1, min(IMG_W - x, w))
    h = max(1, min(IMG_H - y, h))
    return [x, y, w, h]


def build_coco(scenes) -> Dict[str, Any]:
    images     = []
    annotations= []
    ann_id     = 1

    for i, (_, scene_anns) in enumerate(scenes):
        img_id    = i + 1
        file_name = f"scene_{img_id:03d}.png"
        images.append({"id": img_id, "file_name": file_name,
                       "width": IMG_W, "height": IMG_H})
        for ann in scene_anns:
            bbox    = clip_bbox(ann["bbox"])
            cat_id  = CAT_BY_NAME[ann["cat"]]
            area    = bbox[2] * bbox[3]
            annotations.append({
                "id":          ann_id,
                "image_id":    img_id,
                "category_id": cat_id,
                "bbox":        bbox,
                "area":        area,
                "iscrowd":     0,
            })
            ann_id += 1

    return {
        "images":      images,
        "annotations": annotations,
        "categories":  CATEGORIES,
    }

# ── Prediction generators ─────────────────────────────────────────────────────

def jitter_bbox(bbox: List[int], rng: random.Random, jitter: float = 0.08) -> List[int]:
    x, y, w, h = bbox
    dx = int(w * rng.uniform(-jitter, jitter))
    dy = int(h * rng.uniform(-jitter, jitter))
    dw = int(w * rng.uniform(-jitter / 2, jitter / 2))
    dh = int(h * rng.uniform(-jitter / 2, jitter / 2))
    return clip_bbox([x + dx, y + dy, w + dw, h + dh])


def build_predictions_model_a(coco: Dict, scenes, rng: random.Random) -> List[Dict]:
    """
    Model A — Baseline.
    Detects most large/medium objects with moderate confidence.
    Has some FP on distractors. Misses ~35% of small objects.
    Rare class confusion (yellow→green).
    """
    preds = []
    ann_by_img = {}
    for ann in coco["annotations"]:
        ann_by_img.setdefault(ann["image_id"], []).append(ann)

    for img in coco["images"]:
        img_id = img["id"]
        anns   = ann_by_img.get(img_id, [])
        scene_idx = img_id - 1

        for ann in anns:
            area = ann["area"]
            cat_id = ann["category_id"]
            # Skip ~35% of small objects (area < 900) and 10% of medium
            if area < 400:
                if rng.random() < 0.70:
                    continue
            elif area < 900:
                if rng.random() < 0.35:
                    continue
            else:
                if rng.random() < 0.12:
                    continue

            # Class confusion: yellow→green with 15% prob
            if cat_id == 2 and rng.random() < 0.15:
                cat_id = 3

            score = rng.uniform(0.55, 0.88)
            preds.append({
                "image_id":   img_id,
                "category_id":cat_id,
                "bbox":       jitter_bbox(ann["bbox"], rng, 0.07),
                "score":      round(score, 3),
            })

        # FP on background distractors: 35% chance per image with distractors
        has_distractor = any(a["category_id"] == 5 for a in anns)
        if has_distractor and rng.random() < 0.35:
            for ann in anns:
                if ann["category_id"] == 5:
                    fp_cat = rng.choice([1, 3])
                    preds.append({
                        "image_id":   img_id,
                        "category_id":fp_cat,
                        "bbox":       jitter_bbox(ann["bbox"], rng, 0.15),
                        "score":      round(rng.uniform(0.45, 0.65), 3),
                    })
                    break

        # FP on background-only images: 20% chance, 1-2 boxes
        if not anns and rng.random() < 0.20:
            for _ in range(rng.randint(1, 2)):
                x = rng.randint(50, IMG_W - 150)
                y = rng.randint(HORIZON_Y - 120, HORIZON_Y - 20)
                w = rng.randint(30, 70)
                h = rng.randint(40, 90)
                preds.append({
                    "image_id":    img_id,
                    "category_id": rng.choice([1, 3]),
                    "bbox":        [x, y, w, h],
                    "score":       round(rng.uniform(0.42, 0.60), 3),
                })

    return preds


def build_predictions_model_b(coco: Dict, scenes, rng: random.Random) -> List[Dict]:
    """
    Model B — High Recall, more FP.
    Detects almost all objects including small ones with lower scores.
    Many FP on distractors and background-only images.
    More class confusion (red→yellow, yellow→green).
    """
    preds = []
    ann_by_img = {}
    for ann in coco["annotations"]:
        ann_by_img.setdefault(ann["image_id"], []).append(ann)

    for img in coco["images"]:
        img_id = img["id"]
        anns   = ann_by_img.get(img_id, [])

        for ann in anns:
            area   = ann["area"]
            cat_id = ann["category_id"]
            # Miss very few objects — only 5% of small, 5% of others
            if area < 400:
                if rng.random() < 0.05:
                    continue
            else:
                if rng.random() < 0.05:
                    continue

            # More class confusion
            if cat_id == 1 and rng.random() < 0.12:
                cat_id = 2   # red→yellow
            elif cat_id == 2 and rng.random() < 0.20:
                cat_id = 3   # yellow→green
            elif cat_id == 4 and rng.random() < 0.10:
                cat_id = 3   # pedestrian_sign→green_light

            score = rng.uniform(0.40, 0.78)
            preds.append({
                "image_id":   img_id,
                "category_id":cat_id,
                "bbox":       jitter_bbox(ann["bbox"], rng, 0.10),
                "score":      round(score, 3),
            })

        # Heavy FP on distractors: 65% chance, multiple boxes
        has_distractor = any(a["category_id"] == 5 for a in anns)
        if has_distractor and rng.random() < 0.65:
            for ann in anns:
                if ann["category_id"] == 5:
                    for _ in range(rng.randint(1, 2)):
                        fp_cat = rng.choice([1, 2, 3])
                        preds.append({
                            "image_id":   img_id,
                            "category_id":fp_cat,
                            "bbox":       jitter_bbox(ann["bbox"], rng, 0.18),
                            "score":      round(rng.uniform(0.38, 0.65), 3),
                        })

        # Heavy FP on background-only images: 60% chance
        if not anns and rng.random() < 0.60:
            for _ in range(rng.randint(1, 3)):
                x = rng.randint(50, IMG_W - 150)
                y = rng.randint(HORIZON_Y - 130, HORIZON_Y - 15)
                w = rng.randint(25, 80)
                h = rng.randint(35, 100)
                preds.append({
                    "image_id":    img_id,
                    "category_id": rng.choice([1, 2, 3]),
                    "bbox":        [x, y, w, h],
                    "score":       round(rng.uniform(0.35, 0.62), 3),
                })

    return preds


def build_predictions_model_c(coco: Dict, scenes, rng: random.Random) -> List[Dict]:
    """
    Model C — High Precision, misses small objects.
    High-confidence detections, very few FP.
    Skips essentially all small objects (area < 900).
    Rare class confusion.
    """
    preds = []
    ann_by_img = {}
    for ann in coco["annotations"]:
        ann_by_img.setdefault(ann["image_id"], []).append(ann)

    for img in coco["images"]:
        img_id = img["id"]
        anns   = ann_by_img.get(img_id, [])

        for ann in anns:
            area   = ann["area"]
            cat_id = ann["category_id"]

            # Skip virtually all small objects
            if area < 400:
                if rng.random() < 0.92:
                    continue
            elif area < 900:
                if rng.random() < 0.60:
                    continue
            else:
                if rng.random() < 0.10:
                    continue

            # Minimal class confusion
            if cat_id == 4 and rng.random() < 0.08:
                cat_id = 3  # pedestrian_sign→green_light

            score = rng.uniform(0.72, 0.96)
            preds.append({
                "image_id":   img_id,
                "category_id":cat_id,
                "bbox":       jitter_bbox(ann["bbox"], rng, 0.05),
                "score":      round(score, 3),
            })

        # Almost no FP on distractors: 10% chance
        has_distractor = any(a["category_id"] == 5 for a in anns)
        if has_distractor and rng.random() < 0.10:
            for ann in anns:
                if ann["category_id"] == 5:
                    preds.append({
                        "image_id":   img_id,
                        "category_id":rng.choice([1, 3]),
                        "bbox":       jitter_bbox(ann["bbox"], rng, 0.10),
                        "score":      round(rng.uniform(0.50, 0.68), 3),
                    })
                    break

        # Rare FP on background-only images: 8%
        if not anns and rng.random() < 0.08:
            x = rng.randint(100, IMG_W - 200)
            y = rng.randint(HORIZON_Y - 100, HORIZON_Y - 30)
            w = rng.randint(35, 65)
            h = rng.randint(50, 85)
            preds.append({
                "image_id":    img_id,
                "category_id": rng.choice([1, 3]),
                "bbox":        [x, y, w, h],
                "score":       round(rng.uniform(0.52, 0.72), 3),
            })

    return preds

# ── AP metrics ────────────────────────────────────────────────────────────────

def ap_metrics_model_a() -> Dict:
    return {
        "evaluator_name": "showcase_precomputed",
        "generated_at":   "2026-06-03T00:00:00.000Z",
        "ap":             0.524,
        "ap50":           0.741,
        "ap75":           0.558,
        "ap_small":       0.276,
        "ap_medium":      0.551,
        "ap_large":       0.712,
        "ar1":            0.381,
        "ar10":           0.612,
        "ar100":          0.637,
        "ar_small":       0.318,
        "ar_medium":      0.641,
        "ar_large":       0.763,
        "per_class": [
            {"category_id": 1, "category_name": "red_light",
             "ap": 0.581, "ap50": 0.802, "ap75": 0.617, "ar": 0.681},
            {"category_id": 2, "category_name": "yellow_light",
             "ap": 0.432, "ap50": 0.635, "ap75": 0.449, "ar": 0.558},
            {"category_id": 3, "category_name": "green_light",
             "ap": 0.591, "ap50": 0.812, "ap75": 0.622, "ar": 0.695},
            {"category_id": 4, "category_name": "pedestrian_sign",
             "ap": 0.514, "ap50": 0.731, "ap75": 0.540, "ar": 0.626},
            {"category_id": 5, "category_name": "background_distractor",
             "ap": 0.501, "ap50": 0.724, "ap75": 0.528, "ar": 0.624},
        ],
        "warnings": [],
    }


def ap_metrics_model_b() -> Dict:
    return {
        "evaluator_name": "showcase_precomputed",
        "generated_at":   "2026-06-03T00:00:00.000Z",
        "ap":             0.471,
        "ap50":           0.695,
        "ap75":           0.492,
        "ap_small":       0.312,
        "ap_medium":      0.518,
        "ap_large":       0.662,
        "ar1":            0.432,
        "ar10":           0.713,
        "ar100":          0.748,
        "ar_small":       0.391,
        "ar_medium":      0.731,
        "ar_large":       0.821,
        "per_class": [
            {"category_id": 1, "category_name": "red_light",
             "ap": 0.421, "ap50": 0.641, "ap75": 0.441, "ar": 0.718},
            {"category_id": 2, "category_name": "yellow_light",
             "ap": 0.389, "ap50": 0.601, "ap75": 0.402, "ar": 0.691},
            {"category_id": 3, "category_name": "green_light",
             "ap": 0.512, "ap50": 0.741, "ap75": 0.538, "ar": 0.782},
            {"category_id": 4, "category_name": "pedestrian_sign",
             "ap": 0.489, "ap50": 0.718, "ap75": 0.512, "ar": 0.742},
            {"category_id": 5, "category_name": "background_distractor",
             "ap": 0.542, "ap50": 0.775, "ap75": 0.569, "ar": 0.806},
        ],
        "warnings": [],
    }


def ap_metrics_model_c() -> Dict:
    return {
        "evaluator_name": "showcase_precomputed",
        "generated_at":   "2026-06-03T00:00:00.000Z",
        "ap":             0.612,
        "ap50":           0.822,
        "ap75":           0.648,
        "ap_small":       0.189,
        "ap_medium":      0.631,
        "ap_large":       0.792,
        "ar1":            0.441,
        "ar10":           0.651,
        "ar100":          0.672,
        "ar_small":       0.208,
        "ar_medium":      0.661,
        "ar_large":       0.831,
        "per_class": [
            {"category_id": 1, "category_name": "red_light",
             "ap": 0.648, "ap50": 0.861, "ap75": 0.684, "ar": 0.712},
            {"category_id": 2, "category_name": "yellow_light",
             "ap": 0.558, "ap50": 0.768, "ap75": 0.589, "ar": 0.628},
            {"category_id": 3, "category_name": "green_light",
             "ap": 0.661, "ap50": 0.872, "ap75": 0.698, "ar": 0.725},
            {"category_id": 4, "category_name": "pedestrian_sign",
             "ap": 0.541, "ap50": 0.748, "ap75": 0.572, "ar": 0.598},
            {"category_id": 5, "category_name": "background_distractor",
             "ap": 0.652, "ap50": 0.851, "ap75": 0.688, "ar": 0.797},
        ],
        "warnings": [],
    }

# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    rng = random.Random(SEED)
    IMAGES_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Generating scenes...")
    scenes = build_scenes(rng)

    print(f"Saving {len(scenes)} images to {IMAGES_DIR} ...")
    for i, (img, _) in enumerate(scenes):
        name = f"scene_{i + 1:03d}.png"
        img.save(IMAGES_DIR / name, "PNG")
        if (i + 1) % 10 == 0:
            print(f"  {i + 1}/{len(scenes)}")

    print("Building COCO annotations...")
    coco = build_coco(scenes)
    n_ann = len(coco["annotations"])
    print(f"  {len(coco['images'])} images, {n_ann} annotations")

    # Separate seeds for each model so they are independent
    rng_a = random.Random(SEED + 1)
    rng_b = random.Random(SEED + 2)
    rng_c = random.Random(SEED + 3)

    print("Building predictions for Model A (baseline)...")
    preds_a = build_predictions_model_a(coco, scenes, rng_a)
    print(f"  {len(preds_a)} predictions")

    print("Building predictions for Model B (high recall)...")
    preds_b = build_predictions_model_b(coco, scenes, rng_b)
    print(f"  {len(preds_b)} predictions")

    print("Building predictions for Model C (high precision)...")
    preds_c = build_predictions_model_c(coco, scenes, rng_c)
    print(f"  {len(preds_c)} predictions")

    print("Writing JSON files...")

    def write_json(path: Path, data) -> None:
        path.write_text(json.dumps(data, indent=2, ensure_ascii=False))
        print(f"  {path.relative_to(OUT_DIR.parent.parent)}")

    write_json(OUT_DIR / "annotations.json", coco)
    write_json(OUT_DIR / "predictions_model_a.json", preds_a)
    write_json(OUT_DIR / "predictions_model_b.json", preds_b)
    write_json(OUT_DIR / "predictions_model_c.json", preds_c)
    write_json(OUT_DIR / "ap_metrics_model_a.json", ap_metrics_model_a())
    write_json(OUT_DIR / "ap_metrics_model_b.json", ap_metrics_model_b())
    write_json(OUT_DIR / "ap_metrics_model_c.json", ap_metrics_model_c())

    # Summary
    small_gt = sum(1 for a in coco["annotations"] if a["area"] < 1024)
    bg_only  = sum(1 for img in coco["images"]
                   if not any(a["image_id"] == img["id"]
                              for a in coco["annotations"]))
    by_cat = {}
    for a in coco["annotations"]:
        cname = next(c["name"] for c in CATEGORIES if c["id"] == a["category_id"])
        by_cat[cname] = by_cat.get(cname, 0) + 1

    print("\n── Dataset summary ──────────────────────────────────")
    print(f"  Images:           {len(coco['images'])}")
    print(f"  Annotations:      {n_ann}")
    print(f"  Small objects:    {small_gt}  (area < 32²)")
    print(f"  Background-only:  {bg_only}  images with no GT")
    print(f"  Categories:       {', '.join(f'{k}={v}' for k, v in by_cat.items())}")
    print(f"  Model A preds:    {len(preds_a)}")
    print(f"  Model B preds:    {len(preds_b)}")
    print(f"  Model C preds:    {len(preds_c)}")
    print("\nDone.")


if __name__ == "__main__":
    main()
