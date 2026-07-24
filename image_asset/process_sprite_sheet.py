from __future__ import annotations

import argparse
import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image


GRID_SIZE = 3
ALPHA_THRESHOLD = 16
HEAD_SCAN_HEIGHT = 38
FRAME_PADDING_X = 20
FRAME_PADDING_TOP = 24
FRAME_PADDING_BOTTOM = 20


def flood_background(candidate: np.ndarray) -> np.ndarray:
    """Return candidate pixels connected to any image edge."""
    height, width = candidate.shape
    background = np.zeros_like(candidate, dtype=bool)
    queue: deque[tuple[int, int]] = deque()

    for x in range(width):
        for y in (0, height - 1):
            if candidate[y, x] and not background[y, x]:
                background[y, x] = True
                queue.append((y, x))
    for y in range(height):
        for x in (0, width - 1):
            if candidate[y, x] and not background[y, x]:
                background[y, x] = True
                queue.append((y, x))

    while queue:
        y, x = queue.popleft()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                ny, nx = y + dy, x + dx
                if (
                    0 <= ny < height
                    and 0 <= nx < width
                    and candidate[ny, nx]
                    and not background[ny, nx]
                ):
                    background[ny, nx] = True
                    queue.append((ny, nx))
    return background


def remove_background(cell: Image.Image) -> Image.Image:
    rgb = np.asarray(cell.convert("RGB"), dtype=np.float32)
    height, width, _ = rgb.shape

    # The source has a gently varying warm-white background. Estimate it from
    # edge pixels that are bright and low-chroma; the character never touches
    # the left/right edges, even in the bottom row.
    strip = max(8, min(height, width) // 32)
    edge_samples = np.concatenate(
        [
            rgb[:, :strip].reshape(-1, 3),
            rgb[:, -strip:].reshape(-1, 3),
            rgb[:strip].reshape(-1, 3),
            rgb[-strip:].reshape(-1, 3),
        ],
        axis=0,
    )
    bright = edge_samples.mean(axis=1) > 225
    low_chroma = np.ptp(edge_samples, axis=1) < 20
    clean_samples = edge_samples[bright & low_chroma]
    background_color = np.median(clean_samples, axis=0)

    distance = np.linalg.norm(rgb - background_color[None, None, :], axis=2)
    luminance = rgb.mean(axis=2)
    chroma = np.ptp(rgb, axis=2)
    candidate = (distance < 24.0) & (luminance > 222.0) & (chroma < 24.0)
    background = flood_background(candidate)

    alpha = np.where(background, 0.0, 255.0)

    # Recover antialias coverage only along the exterior edge. Interior light
    # garment pixels remain fully opaque.
    adjacent_to_background = np.zeros_like(background)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx == 0 and dy == 0:
                continue
            shifted = np.zeros_like(background)
            ys = slice(max(0, dy), height + min(0, dy))
            xs = slice(max(0, dx), width + min(0, dx))
            src_ys = slice(max(0, -dy), height - max(0, dy))
            src_xs = slice(max(0, -dx), width - max(0, dx))
            shifted[ys, xs] = background[src_ys, src_xs]
            adjacent_to_background |= shifted

    fringe = (~background) & adjacent_to_background
    coverage = np.clip((distance - 2.0) / 22.0, 0.0, 1.0)
    alpha[fringe] = np.minimum(alpha[fringe], coverage[fringe] * 255.0)

    # Unmix the warm background from partially covered edge pixels to avoid
    # a pale halo when the PNG is drawn over dark game backgrounds.
    out_rgb = rgb.copy()
    partial = fringe & (alpha > 0.0) & (alpha < 255.0)
    a = alpha[partial, None] / 255.0
    out_rgb[partial] = np.clip(
        (rgb[partial] - (1.0 - a) * background_color[None, :]) / a,
        0,
        255,
    )

    rgba = np.dstack([out_rgb, alpha]).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def content_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = np.asarray(image.getchannel("A"))
    ys, xs = np.where(alpha >= ALPHA_THRESHOLD)
    if len(xs) == 0:
        raise ValueError("No foreground pixels were detected")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def head_anchor_x(image: Image.Image, bbox: tuple[int, int, int, int]) -> float:
    alpha = np.asarray(image.getchannel("A"))
    left, top, right, bottom = bbox
    scan_bottom = min(bottom, top + HEAD_SCAN_HEIGHT)
    row_centers: list[float] = []
    for y in range(top, scan_bottom):
        xs = np.flatnonzero(alpha[y] >= 96)
        if len(xs) >= 2:
            row_centers.append((float(xs[0]) + float(xs[-1])) / 2.0)
    if not row_centers:
        return (left + right - 1) / 2.0
    return float(np.median(row_centers))


def round_up_even(value: float) -> int:
    integer = int(np.ceil(value))
    return integer if integer % 2 == 0 else integer + 1


def process(source: Path, output_dir: Path) -> dict:
    sheet = Image.open(source).convert("RGB")
    if sheet.width % GRID_SIZE or sheet.height % GRID_SIZE:
        raise ValueError(
            f"Expected a 3x3 sheet with divisible dimensions, got {sheet.size}"
        )

    cell_width = sheet.width // GRID_SIZE
    cell_height = sheet.height // GRID_SIZE
    extracted: list[Image.Image] = []
    metadata: list[dict] = []

    for row in range(GRID_SIZE):
        for col in range(GRID_SIZE):
            cell = sheet.crop(
                (
                    col * cell_width,
                    row * cell_height,
                    (col + 1) * cell_width,
                    (row + 1) * cell_height,
                )
            )
            rgba = remove_background(cell)
            bbox = content_bbox(rgba)
            anchor_x = head_anchor_x(rgba, bbox)
            extracted.append(rgba)
            metadata.append(
                {
                    "source_cell": [row, col],
                    "source_bbox": list(bbox),
                    "source_head_anchor": [anchor_x, float(bbox[1])],
                }
            )

    left_extent = max(
        anchor["source_head_anchor"][0] - anchor["source_bbox"][0]
        for anchor in metadata
    )
    right_extent = max(
        anchor["source_bbox"][2] - anchor["source_head_anchor"][0]
        for anchor in metadata
    )
    down_extent = max(
        anchor["source_bbox"][3] - anchor["source_bbox"][1]
        for anchor in metadata
    )

    canvas_width = round_up_even(
        2.0 * max(left_extent, right_extent) + 2 * FRAME_PADDING_X
    )
    canvas_height = round_up_even(
        FRAME_PADDING_TOP + down_extent + FRAME_PADDING_BOTTOM
    )
    target_anchor_x = canvas_width // 2
    target_anchor_y = FRAME_PADDING_TOP

    output_dir.mkdir(parents=True, exist_ok=True)
    aligned_frames: list[Image.Image] = []
    for index, (rgba, frame_meta) in enumerate(zip(extracted, metadata), start=1):
        left, top, right, bottom = frame_meta["source_bbox"]
        crop = rgba.crop((left, top, right, bottom))
        source_anchor_x = frame_meta["source_head_anchor"][0] - left
        paste_x = int(round(target_anchor_x - source_anchor_x))
        paste_y = target_anchor_y

        frame = Image.new("RGBA", (canvas_width, canvas_height), (0, 0, 0, 0))
        frame.alpha_composite(crop, (paste_x, paste_y))
        frame_path = output_dir / f"frame_{index:02d}.png"
        frame.save(frame_path, optimize=True)
        aligned_frames.append(frame)

        frame_meta.update(
            {
                "output": frame_path.name,
                "output_size": [canvas_width, canvas_height],
                "output_head_anchor": [target_anchor_x, target_anchor_y],
                "paste_offset": [paste_x, paste_y],
            }
        )

    preview = Image.new(
        "RGBA",
        (canvas_width * GRID_SIZE, canvas_height * GRID_SIZE),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(aligned_frames):
        row, col = divmod(index, GRID_SIZE)
        preview.alpha_composite(frame, (col * canvas_width, row * canvas_height))
    preview_path = output_dir / "sequence_preview.png"
    preview.save(preview_path, optimize=True)

    manifest = {
        "source": str(source),
        "order": "left-to-right, top-to-bottom",
        "frame_count": len(aligned_frames),
        "frame_size": [canvas_width, canvas_height],
        "head_anchor": [target_anchor_x, target_anchor_y],
        "frames": metadata,
    }
    (output_dir / "sequence_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    manifest = process(args.source, args.output_dir)
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
