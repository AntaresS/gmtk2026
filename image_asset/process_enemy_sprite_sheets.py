from __future__ import annotations

import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image


GRID_COLUMNS = 4
GRID_ROWS = 3
FRAME_SIZE = 544
FRAME_COUNT = 6
HEAD_ANCHOR = (FRAME_SIZE // 2, 121)
TARGET_HEAD_TO_BOTTOM = 264
ALPHA_THRESHOLD = 16

ROOT = Path(__file__).resolve().parent.parent
SOURCE_ROOT = ROOT / "image_asset"
OUTPUT_ROOT = ROOT / "assets" / "enemy_frames"

SHEET_SPECS = {
    "normal_walk": ("enemy_normal_walk", "last", True),
    "normal_heal_walk": ("enemy_normal_heal_walk", "last", False),
    "boomer_walk": ("enemy_boomer_walk", "last", False),
    "normal_fly": ("enemy_normal_fly", "first", False),
    "elite_walk": ("enemy_elite_walk", "first", False),
    "elite_fly": ("enemy_elite_fly", "first", False),
}

# The healer sheet moves the character substantially between source cells and
# its bright particles make automatic hair detection ambiguous. These six
# hand-authored points mark the center of the large back gourd in the selected
# last six cells. Aligning this prop keeps the silhouette stable while the
# legs, cloth, and healing lights continue to animate around it.
HEALER_GOURD_ANCHORS = (
    (151.0, 130.0),
    (106.0, 128.0),
    (205.0, 119.0),
    (166.0, 110.0),
    (154.0, 111.0),
    (145.0, 105.0),
)
HEALER_GOURD_TARGET = (FRAME_SIZE // 2, 180)
FLY_BOOMER_CORE_TARGET = (FRAME_SIZE // 2, 153)
FLY_BOOMER_SCALE = 0.96


def flood_background(candidate: np.ndarray) -> np.ndarray:
    """Return candidate pixels connected to an edge of one source cell."""
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


def detect_head(
    rgb: np.ndarray,
    alpha: np.ndarray | None = None,
) -> tuple[float, float]:
    """Find the central dark hair, helm, horns, or core used as head anchor."""
    height, width, _ = rgb.shape
    luminance = rgb.mean(axis=2)
    central = np.zeros((height, width), dtype=bool)
    central[:, int(width * 0.38) : int(width * 0.62)] = True
    central[int(height * 0.66) :, :] = False
    dark = (luminance < 120.0) & central
    if alpha is not None:
        dark &= alpha >= ALPHA_THRESHOLD
    ys, xs = np.where(dark)
    if len(xs) == 0:
        raise ValueError("Could not locate a central dark head anchor")

    top = int(ys.min())
    head_band = dark & (
        np.indices(dark.shape)[0] <= min(top + 44, height - 1)
    )
    head_ys, head_xs = np.where(head_band)
    if len(head_xs) == 0:
        return float(width / 2), float(top)
    return float(np.median(head_xs)), float(top)


def remove_background(
    cell: Image.Image,
) -> tuple[Image.Image, tuple[float, float]]:
    """Remove the warm studio matte and its connected neutral floor shadow."""
    rgb = np.asarray(cell.convert("RGB"), dtype=np.float32)
    height, width, _ = rgb.shape
    head_anchor = detect_head(rgb)
    luminance = rgb.mean(axis=2)
    chroma = np.ptp(rgb, axis=2)
    red, green, blue = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]

    # The supplied matrices share a bright, warm, low-chroma background.
    # Connectivity preserves pale costume panels and the healer's green glow.
    candidate = (
        (luminance > 142.0)
        & (chroma < 26.0)
        & (red + 4.0 >= green)
        & (green + 4.0 >= blue)
    )
    edge_strip = np.zeros_like(candidate, dtype=bool)
    edge_strip[:3, :] = True
    edge_strip[-3:, :] = True
    edge_strip[:, :3] = True
    edge_strip[:, -3:] = True
    candidate |= edge_strip & (luminance > 180.0) & (chroma < 34.0)
    background = flood_background(candidate)

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
    clean = (edge_samples.mean(axis=1) > 200.0) & (
        np.ptp(edge_samples, axis=1) < 34.0
    )
    background_color = np.median(
        edge_samples[clean] if np.any(clean) else edge_samples,
        axis=0,
    )
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
            source_ys = slice(max(0, -dy), height - max(0, dy))
            source_xs = slice(max(0, -dx), width - max(0, dx))
            shifted[ys, xs] = background[source_ys, source_xs]
            adjacent_to_background |= shifted

    fringe = (~background) & adjacent_to_background
    coverage = np.clip((distance - 3.0) / 28.0, 0.0, 1.0)
    alpha[fringe] = coverage[fringe] * 255.0

    out_rgb = rgb.copy()
    partial = fringe & (alpha > 6.0) & (alpha < 249.0)
    matte_alpha = alpha[partial, None] / 255.0
    out_rgb[partial] = np.clip(
        (
            rgb[partial]
            - (1.0 - matte_alpha) * background_color[None, :]
        )
        / matte_alpha,
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


def find_single_png(directory: Path) -> Path | None:
    images = sorted(
        path
        for path in directory.glob("*.png")
        if not path.name.endswith("_preview.png")
    )
    if not images:
        return None
    return images[0]


def extract_selected_cells(
    source: Path,
    selection: str,
) -> list[Image.Image]:
    # Keep source alpha intact. Legacy matte sheets are converted to RGB later
    # by remove_background(), while authored transparent sheets bypass it.
    sheet = Image.open(source).convert("RGBA")
    if sheet.width % GRID_COLUMNS or sheet.height % GRID_ROWS:
        raise ValueError(
            "Expected a 4x3 sheet with divisible dimensions, "
            f"got {sheet.size}: {source}"
        )
    cell_width = sheet.width // GRID_COLUMNS
    cell_height = sheet.height // GRID_ROWS
    cells: list[Image.Image] = []
    for row in range(GRID_ROWS):
        for column in range(GRID_COLUMNS):
            cells.append(
                sheet.crop(
                    (
                        column * cell_width,
                        row * cell_height,
                        (column + 1) * cell_width,
                        (row + 1) * cell_height,
                    )
                )
            )
    return cells[:FRAME_COUNT] if selection == "first" else cells[-FRAME_COUNT:]


def extract_grid_cells(
    source: Path,
    columns: int,
    rows: int,
) -> list[Image.Image]:
    sheet = Image.open(source).convert("RGBA")
    if sheet.width % columns or sheet.height % rows:
        raise ValueError(
            f"Expected a divisible {columns}x{rows} sheet, "
            f"got {sheet.size}: {source}"
        )
    cell_width = sheet.width // columns
    cell_height = sheet.height // rows
    return [
        sheet.crop(
            (
                column * cell_width,
                row * cell_height,
                (column + 1) * cell_width,
                (row + 1) * cell_height,
            )
        )
        for row in range(rows)
        for column in range(columns)
    ]


def detect_purple_core(cell: Image.Image) -> tuple[float, float]:
    """Return the energy-core center used as the flying bomber's head."""
    rgba = np.asarray(cell.convert("RGBA"), dtype=np.float32)
    red, green, blue, alpha = [rgba[:, :, index] for index in range(4)]
    rows, columns = np.indices(alpha.shape)
    height, width = alpha.shape
    core = (
        (alpha > 32.0)
        & (blue > 90.0)
        & (red > 70.0)
        & (blue > green * 1.12)
        & (red > green * 1.12)
        & (rows < height * 0.55)
        & (columns > width * 0.2)
        & (columns < width * 0.8)
    )
    weights = np.maximum(red + blue - 2.0 * green, 0.0)
    weights *= alpha / 255.0
    weights *= core
    total = float(weights.sum())
    if total <= 0.0:
        raise ValueError("Could not locate the flying bomber's purple core")
    return (
        float((columns * weights).sum() / total),
        float((rows * weights).sum() / total),
    )


def align_fixed_registration(
    cells: list[Image.Image],
    source_anchor: tuple[float, float],
    target_anchor: tuple[int, int],
    scale: float,
) -> tuple[list[Image.Image], list[dict]]:
    """Keep a source matrix registered while moving its first-frame head."""
    paste_x = int(round(target_anchor[0] - source_anchor[0] * scale))
    paste_y = int(round(target_anchor[1] - source_anchor[1] * scale))
    frames: list[Image.Image] = []
    metadata: list[dict] = []
    for cell in cells:
        rgba = cell.convert("RGBA")
        resized = rgba.resize(
            (
                max(1, int(round(rgba.width * scale))),
                max(1, int(round(rgba.height * scale))),
            ),
            Image.Resampling.LANCZOS,
        )
        frame = Image.new(
            "RGBA",
            (FRAME_SIZE, FRAME_SIZE),
            (0, 0, 0, 0),
        )
        frame.alpha_composite(resized, (paste_x, paste_y))
        frames.append(frame)
        metadata.append(
            {
                "source_bbox": list(content_bbox(rgba)),
                "source_alignment_anchor": list(source_anchor),
                "output_alignment_anchor": list(target_anchor),
                "scale": scale,
                "paste_offset": [paste_x, paste_y],
            }
        )
    return frames, metadata


def align_frames(
    cells: list[Image.Image],
    alignment_anchors: tuple[tuple[float, float], ...] | None = None,
    target_anchor: tuple[int, int] = HEAD_ANCHOR,
    preserve_alpha: bool = False,
    fixed_scale: float | None = None,
) -> tuple[list[Image.Image], list[dict]]:
    if alignment_anchors is not None and len(alignment_anchors) != len(cells):
        raise ValueError("Alignment-anchor count must match selected frames")
    extracted: list[Image.Image] = []
    metadata: list[dict] = []
    body_heights: list[float] = []

    for index, cell in enumerate(cells):
        if preserve_alpha:
            rgba = cell.convert("RGBA")
            rgba_array = np.asarray(rgba, dtype=np.float32)
            head_anchor = detect_head(
                rgba_array[:, :, :3],
                rgba_array[:, :, 3],
            )
        else:
            rgba, head_anchor = remove_background(cell)
        bbox = content_bbox(rgba)
        alignment_anchor = (
            alignment_anchors[index]
            if alignment_anchors is not None
            else head_anchor
        )
        extracted.append(rgba)
        body_height = max(float(bbox[3]) - head_anchor[1], 1.0)
        body_heights.append(body_height)
        metadata.append(
            {
                "source_bbox": list(bbox),
                "source_head_anchor": list(head_anchor),
                "source_alignment_anchor": list(alignment_anchor),
            }
        )

    shared_body_height = float(np.median(np.asarray(body_heights)))
    shared_scale = (
        fixed_scale
        if fixed_scale is not None
        else TARGET_HEAD_TO_BOTTOM / shared_body_height
    )
    aligned: list[Image.Image] = []
    for rgba, frame_metadata in zip(extracted, metadata):
        source_head_x, source_head_y = frame_metadata["source_head_anchor"]
        source_anchor_x, source_anchor_y = frame_metadata[
            "source_alignment_anchor"
        ]
        resized = rgba.resize(
            (
                max(1, int(round(rgba.width * shared_scale))),
                max(1, int(round(rgba.height * shared_scale))),
            ),
            Image.Resampling.LANCZOS,
        )
        paste_x = int(round(target_anchor[0] - source_anchor_x * shared_scale))
        paste_y = int(round(target_anchor[1] - source_anchor_y * shared_scale))
        frame = Image.new(
            "RGBA",
            (FRAME_SIZE, FRAME_SIZE),
            (0, 0, 0, 0),
        )
        frame.alpha_composite(resized, (paste_x, paste_y))
        aligned.append(frame)
        frame_metadata.update(
            {
                "output_alignment_anchor": list(target_anchor),
                "output_head_position": [
                    paste_x + source_head_x * shared_scale,
                    paste_y + source_head_y * shared_scale,
                ],
                "scale": shared_scale,
                "paste_offset": [paste_x, paste_y],
            }
        )
    return aligned, metadata


def save_atlas(
    name: str,
    frames: list[Image.Image],
    metadata: list[dict],
    alignment_name: str = "head",
    target_anchor: tuple[int, int] = HEAD_ANCHOR,
) -> None:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    atlas = Image.new(
        "RGBA",
        (FRAME_SIZE * len(frames), FRAME_SIZE),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(frames):
        atlas.alpha_composite(frame, (index * FRAME_SIZE, 0))
    atlas.save(OUTPUT_ROOT / f"{name}.png", optimize=True)
    (OUTPUT_ROOT / f"{name}.json").write_text(
        json.dumps(
            {
                "frame_count": len(frames),
                "frame_size": [FRAME_SIZE, FRAME_SIZE],
                "alignment": alignment_name,
                "alignment_anchor": list(target_anchor),
                "frames": metadata,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )


def process_explosion_directory() -> bool:
    source_dir = SOURCE_ROOT / "enemy_boomer_boom"
    images = sorted(source_dir.glob("*.png"))
    if not images:
        return False
    if len(images) == 1:
        sheet = Image.open(images[0]).convert("RGB")
        if sheet.width % 3 or sheet.height % 3:
            raise ValueError(
                "Expected the explosion sheet to be a divisible 3x3 matrix, "
                f"got {sheet.size}: {images[0]}"
            )
        cell_width = sheet.width // 3
        cell_height = sheet.height // 3
        cells = [
            sheet.crop(
                (
                    column * cell_width,
                    row * cell_height,
                    (column + 1) * cell_width,
                    (row + 1) * cell_height,
                )
            )
            for row in range(3)
            for column in range(3)
        ]
    else:
        cells = [Image.open(path).convert("RGB") for path in images]

    # Explosion frames lose the character's head near the end. Keep the
    # source matrix registration instead of attempting per-frame head finding.
    transparent_cells: list[Image.Image] = []
    metadata: list[dict] = []
    for cell in cells:
        rgb = np.asarray(cell.convert("RGB"), dtype=np.float32)
        luminance = rgb.mean(axis=2)
        chroma = np.ptp(rgb, axis=2)
        red, green, blue = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
        candidate = (
            (luminance > 142.0)
            & (chroma < 28.0)
            & (red + 5.0 >= green)
            & (green + 5.0 >= blue)
        )
        background = flood_background(candidate)
        alpha = np.where(background, 0, 255).astype(np.uint8)
        rgba = Image.fromarray(
            np.dstack([rgb.astype(np.uint8), alpha]),
            "RGBA",
        )
        transparent_cells.append(rgba)
        metadata.append({"source_bbox": list(content_bbox(rgba))})

    first_rgb = np.asarray(cells[0].convert("RGB"), dtype=np.float32)
    first_head_x, first_head_y = detect_head(first_rgb)
    first_bottom = float(metadata[0]["source_bbox"][3])
    shared_scale = TARGET_HEAD_TO_BOTTOM / max(
        first_bottom - first_head_y,
        1.0,
    )
    paste_x = int(round(HEAD_ANCHOR[0] - first_head_x * shared_scale))
    paste_y = int(round(HEAD_ANCHOR[1] - first_head_y * shared_scale))

    aligned: list[Image.Image] = []
    for rgba, frame_metadata in zip(transparent_cells, metadata):
        resized = rgba.resize(
            (
                max(1, int(round(rgba.width * shared_scale))),
                max(1, int(round(rgba.height * shared_scale))),
            ),
            Image.Resampling.LANCZOS,
        )
        frame = Image.new(
            "RGBA",
            (FRAME_SIZE, FRAME_SIZE),
            (0, 0, 0, 0),
        )
        frame.alpha_composite(resized, (paste_x, paste_y))
        aligned.append(frame)
        frame_metadata.update(
            {
                "output_head_anchor": list(HEAD_ANCHOR),
                "scale": shared_scale,
                "paste_offset": [paste_x, paste_y],
                "registration": "fixed from first explosion frame",
            }
        )
    save_atlas("boomer_boom", aligned, metadata)
    return True


def process_flying_bomber_sheets() -> tuple[bool, bool]:
    fly_source = find_single_png(SOURCE_ROOT / "enemy_flyboomer_fly")
    boom_source = find_single_png(SOURCE_ROOT / "enemy_flyboomer_boom")
    fly_processed = False
    boom_processed = False

    if fly_source is not None:
        fly_cells = extract_grid_cells(fly_source, 3, 3)
        fly_anchors = tuple(detect_purple_core(cell) for cell in fly_cells)
        fly_frames, fly_metadata = align_frames(
            fly_cells,
            fly_anchors,
            FLY_BOOMER_CORE_TARGET,
            preserve_alpha=True,
            fixed_scale=FLY_BOOMER_SCALE,
        )
        save_atlas(
            "fly_boomer_fly",
            fly_frames,
            fly_metadata,
            "purple head core center",
            FLY_BOOMER_CORE_TARGET,
        )
        fly_processed = True

    if boom_source is not None:
        boom_cells = extract_grid_cells(boom_source, 3, 3)
        first_core = detect_purple_core(boom_cells[0])
        boom_frames, boom_metadata = align_fixed_registration(
            boom_cells,
            first_core,
            FLY_BOOMER_CORE_TARGET,
            FLY_BOOMER_SCALE,
        )
        save_atlas(
            "fly_boomer_boom",
            boom_frames,
            boom_metadata,
            "first-frame purple head core center",
            FLY_BOOMER_CORE_TARGET,
        )
        boom_processed = True

    return fly_processed, boom_processed


def main() -> None:
    processed: list[str] = []
    missing: list[str] = []
    for output_name, (
        source_directory,
        selection,
        preserve_alpha,
    ) in SHEET_SPECS.items():
        source = find_single_png(SOURCE_ROOT / source_directory)
        if source is None:
            missing.append(source_directory)
            continue
        cells = extract_selected_cells(source, selection)
        if output_name == "normal_heal_walk":
            aligned, metadata = align_frames(
                cells,
                HEALER_GOURD_ANCHORS,
                HEALER_GOURD_TARGET,
            )
            save_atlas(
                output_name,
                aligned,
                metadata,
                "large back gourd center",
                HEALER_GOURD_TARGET,
            )
        else:
            aligned, metadata = align_frames(
                cells,
                preserve_alpha=preserve_alpha,
            )
            save_atlas(output_name, aligned, metadata)
        processed.append(output_name)

    if process_explosion_directory():
        processed.append("boomer_boom")
    else:
        missing.append("enemy_boomer_boom")

    fly_boomer_fly, fly_boomer_boom = process_flying_bomber_sheets()
    if fly_boomer_fly:
        processed.append("fly_boomer_fly")
    else:
        missing.append("enemy_flyboomer_fly")
    if fly_boomer_boom:
        processed.append("fly_boomer_boom")
    else:
        missing.append("enemy_flyboomer_boom")

    print(
        json.dumps(
            {
                "processed": processed,
                "missing": missing,
                "output": str(OUTPUT_ROOT),
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
