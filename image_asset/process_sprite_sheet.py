from __future__ import annotations

import argparse
import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image


GRID_SIZE = 3
ALPHA_THRESHOLD = 16
OUTPUT_SIZE = 544
# Relative to the canvas center this matches the legacy 418px flying frames:
# head y ~= 57 and bottom y ~= 321. The larger canvas leaves room for wide
# sleeves and the Nascent Soul halo without changing the in-game body size.
TARGET_HEAD_ANCHOR = (OUTPUT_SIZE // 2, 121)
TARGET_HEAD_TO_BOTTOM = 264


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


def detect_dark_head(
    rgb: np.ndarray,
    alpha: np.ndarray | None = None,
) -> tuple[float, float]:
    """Locate the dark hair/head independently of bright halos and ribbons."""
    height, width, _ = rgb.shape
    luminance = rgb.mean(axis=2)
    central = np.zeros((height, width), dtype=bool)
    central[:, int(width * 0.28) : int(width * 0.72)] = True
    central[int(height * 0.62) :, :] = False
    dark = (luminance < 115.0) & central
    if alpha is not None:
        dark &= alpha >= 128
    ys, xs = np.where(dark)
    if len(xs) == 0:
        raise ValueError("Could not locate the character's dark head/hair")

    top = int(ys.min())
    head_band = dark & (
        np.indices(dark.shape)[0] <= min(top + 44, height - 1)
    )
    head_ys, head_xs = np.where(head_band)
    if len(head_xs) == 0:
        return float(width / 2), float(top)
    return float(np.median(head_xs)), float(top)


def remove_background(cell: Image.Image) -> tuple[Image.Image, tuple[float, float]]:
    rgb = np.asarray(cell.convert("RGB"), dtype=np.float32)
    height, width, _ = rgb.shape
    head_anchor = detect_dark_head(rgb)

    # Both supplied sheets use a warm, low-chroma studio background. Treat
    # neutral warm pixels (including the soft floor shadow) as removable, but
    # only when they connect to the cell edge. Connectivity protects enclosed
    # white robe panels from being punched out.
    luminance = rgb.mean(axis=2)
    chroma = np.ptp(rgb, axis=2)
    red, green, blue = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    candidate = (
        (luminance > 145.0)
        # A narrow neutral band removes the warm studio matte while retaining
        # the slightly blue/gray white fabric at open sleeve edges.
        & (chroma < 24.0)
        & (red + 3.0 >= green)
        & (green + 3.0 >= blue)
    )
    # Only force-seed edge pixels that are clearly background-toned.
    # Unconditional seeding of the full border strip causes the flood-fill to
    # walk into light-coloured sleeves / arms that extend near the cell edge —
    # those arms then become transparent.  Restricting seeds to pixels with
    # high luminance AND low chroma keeps the behaviour correct for plain
    # studio backgrounds while preserving limbs near the boundary.
    edge_strip = np.zeros_like(candidate, dtype=bool)
    edge_strip[:3, :] = True
    edge_strip[-3:, :] = True
    edge_strip[:, :3] = True
    edge_strip[:, -3:] = True
    candidate |= edge_strip & (luminance > 185.0) & (chroma < 30.0)
    background = flood_background(candidate)

    # Bright halo rings can enclose patches of the original background above
    # the head. Those patches are safe to clear because no robe occupies this
    # vertical region.
    rows = np.indices(background.shape)[0]
    background |= candidate & (rows < int(head_anchor[1]))

    # Estimate the matte color from clean edge pixels for antialias recovery.
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
    clean = (edge_samples.mean(axis=1) > 205.0) & (
        np.ptp(edge_samples, axis=1) < 30.0
    )
    background_color = np.median(edge_samples[clean], axis=0)
    distance = np.linalg.norm(
        rgb - background_color[None, None, :],
        axis=2,
    )

    alpha = np.where(background, 0.0, 255.0)
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
    coverage = np.clip((distance - 3.0) / 28.0, 0.0, 1.0)
    alpha[fringe] = coverage[fringe] * 255.0

    # Unmix the warm source matte from partially covered exterior pixels so
    # the frames do not show a pale fringe over the game's darker terrain.
    out_rgb = rgb.copy()
    partial = fringe & (alpha > 6.0) & (alpha < 249.0)
    a = alpha[partial, None] / 255.0
    out_rgb[partial] = np.clip(
        (rgb[partial] - (1.0 - a) * background_color[None, :]) / a,
        0,
        255,
    )

    rgba = np.dstack([out_rgb, alpha]).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA"), head_anchor


def content_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = np.asarray(image.getchannel("A"))
    ys, xs = np.where(alpha >= ALPHA_THRESHOLD)
    if len(xs) == 0:
        raise ValueError("No foreground pixels were detected")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def process(
    source: Path,
    output_dir: Path,
    prefix: str,
    preserve_alpha: bool = False,
) -> dict:
    sheet = Image.open(source).convert("RGBA")
    if sheet.width % GRID_SIZE or sheet.height % GRID_SIZE:
        raise ValueError(
            f"Expected a 3x3 sheet with divisible dimensions, got {sheet.size}"
        )
    if preserve_alpha and sheet.getchannel("A").getextrema()[0] == 255:
        raise ValueError(
            "--preserve-alpha requires a source with transparent pixels"
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
            if preserve_alpha:
                rgba = cell.copy()
                cell_data = np.asarray(rgba, dtype=np.uint8)
                head_anchor = detect_dark_head(
                    cell_data[:, :, :3].astype(np.float32),
                    cell_data[:, :, 3],
                )
            else:
                rgba, head_anchor = remove_background(cell)
            bbox = content_bbox(rgba)
            extracted.append(rgba)
            metadata.append(
                {
                    "source_cell": [row, col],
                    "source_bbox": list(bbox),
                    "source_head_anchor": list(head_anchor),
                }
            )

    output_dir.mkdir(parents=True, exist_ok=True)
    aligned_frames: list[Image.Image] = []
    for index, (rgba, frame_meta) in enumerate(zip(extracted, metadata)):
        left, top, right, bottom = frame_meta["source_bbox"]
        source_head_x, source_head_y = frame_meta["source_head_anchor"]
        body_height = max(float(bottom) - source_head_y, 1.0)
        scale = TARGET_HEAD_TO_BOTTOM / body_height
        resized = rgba.resize(
            (
                max(1, int(round(rgba.width * scale))),
                max(1, int(round(rgba.height * scale))),
            ),
            Image.Resampling.LANCZOS,
        )

        paste_x = int(round(TARGET_HEAD_ANCHOR[0] - source_head_x * scale))
        paste_y = int(round(TARGET_HEAD_ANCHOR[1] - source_head_y * scale))
        frame = Image.new(
            "RGBA",
            (OUTPUT_SIZE, OUTPUT_SIZE),
            (0, 0, 0, 0),
        )
        frame.alpha_composite(resized, (paste_x, paste_y))
        frame_path = output_dir / f"{prefix}_{index:02d}.png"
        frame.save(frame_path, optimize=True)
        aligned_frames.append(frame)

        frame_meta.update(
            {
                "output": frame_path.name,
                "output_size": [OUTPUT_SIZE, OUTPUT_SIZE],
                "output_head_anchor": list(TARGET_HEAD_ANCHOR),
                "scale": scale,
                "paste_offset": [paste_x, paste_y],
            }
        )

    preview = Image.new(
        "RGBA",
        (OUTPUT_SIZE * GRID_SIZE, OUTPUT_SIZE * GRID_SIZE),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(aligned_frames):
        row, col = divmod(index, GRID_SIZE)
        preview.alpha_composite(
            frame,
            (col * OUTPUT_SIZE, row * OUTPUT_SIZE),
        )
    preview_path = output_dir / f"{prefix}_preview.png"
    preview.save(preview_path, optimize=True)

    manifest = {
        "source": str(source),
        "order": "left-to-right, top-to-bottom",
        "frame_count": len(aligned_frames),
        "frame_size": [OUTPUT_SIZE, OUTPUT_SIZE],
        "head_anchor": list(TARGET_HEAD_ANCHOR),
        "target_head_to_bottom": TARGET_HEAD_TO_BOTTOM,
        "source_alpha_preserved": preserve_alpha,
        "frames": metadata,
    }
    (output_dir / f"{prefix}_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--prefix", required=True)
    parser.add_argument(
        "--preserve-alpha",
        action="store_true",
        help="Use the source alpha unchanged; do not run background removal.",
    )
    args = parser.parse_args()
    manifest = process(
        args.source,
        args.output_dir,
        args.prefix,
        args.preserve_alpha,
    )
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
