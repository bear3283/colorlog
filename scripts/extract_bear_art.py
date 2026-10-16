#!/usr/bin/env python3
"""수채화 곰 원화에서 앱이 쓸 세 겹(연필 · 실루엣 · 원화 그대로)을 뽑아 에셋 카탈로그로 내보낸다.

곰의 모양과 연필 선은 원화를 그대로 쓰고, 몸 안쪽 물감만 앱이 사용자의 색으로 칠한다.
원화를 바꾸거나 자세를 더하면 SOURCES를 고치고 이 스크립트를 다시 돌리면 된다.

    python3 scripts/extract_bear_art.py <원화 폴더>

뽑는 것 (자세마다):
  · ink  — 갈색 연필 선과 표정. 원화의 색과 결을 그대로 두고 어두운 정도를 알파로 쓴다.
           물감 얼룩이 섞이지 않도록 갈색 계열만 남긴다.
  · mask — 몸의 외곽선 안쪽. 물감이 이 밖으로 번지지 않게 막는다.
  · keep — 사용자의 색으로 덮지 않고 원화 그대로 두는 자리.
           흰 주둥이(벌린 입 속 혀 포함), 몸 안의 소품(책 · 도넛), 몸 밖의 색 있는 표시
           (하트 · 물방울 · 눈물). 갈색 선만 있는 표시(z, 음표)는 ink에 이미 있다.

마지막에 자세별 20×20 점유 격자를 Swift 배열로 출력한다. 앱은 이 격자로
물감 얼룩을 실루엣 안에만 놓는다.
"""

import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Shared" / "BearArt.xcassets"
SIZE = 900
GRID = 20

FIVE = "Gemini_Generated_Image_az054oaz054oaz05.png"
EIGHT = "Gemini_Generated_Image_5xs0p85xs0p85xs0.png"
PROPS = "Gemini_Generated_Image_4o4nqe4o4nqe4o4n.png"

# (자세, 원화 파일, 잘라 낼 영역 x0, y0, x1, y1 또는 None, 지울 영역 목록)
# 시트에서 잘라 낼 때는 이웃 곰과 겹치지 않게 경계를 잡고, 칸 안에 걸친 이름표는 지운다.
SOURCES = [
    ("standing", "Gemini_Generated_Image_disuwydisuwydisu.png", None, []),
    ("waving", "Gemini_Generated_Image_muk72kmuk72kmuk7.png", None, []),
    ("sleeping", "Gemini_Generated_Image_z3bcc0z3bcc0z3bc.png", None, []),
    ("sitting", "Gemini_Generated_Image_otoz1xotoz1xotoz.png", None, []),
    ("jumping", FIVE, (1612, 270, 2145, 1040), []),
    ("cheering", FIVE, (2145, 270, 2740, 1040), []),
    ("running", EIGHT, (75, 260, 682, 815), []),
    ("eating", EIGHT, (682, 260, 1205, 815), []),
    ("reading", EIGHT, (1215, 250, 1995, 795), []),
    ("proud", EIGHT, (2105, 250, 2645, 800), []),
    ("pointing", EIGHT, (225, 835, 935, 1362), [(240, 845, 522, 955), (795, 845, 1035, 960)]),
    ("peeking", EIGHT, (1140, 985, 1575, 1348), []),
    ("angry", EIGHT, (1615, 728, 2142, 1348), []),
    ("crying", EIGHT, (2150, 798, 2652, 1348), []),
    # 소품 시트. 위 줄 오른쪽 모자 곰은 아래 줄 모자 곰과 표정만 달라 하나(아래 줄)만 쓴다.
    ("sunglasses", PROPS, (140, 120, 690, 695), []),
    ("music", PROPS, (815, 90, 1370, 695), []),
    ("umbrella", PROPS, (1500, 30, 2120, 695), []),
    ("hat", PROPS, (160, 830, 640, 1400), []),
    ("workout", PROPS, (1030, 835, 1725, 1400), []),
    ("studying", PROPS, (2120, 870, 2665, 1400), []),
]


def disk(radius):
    y, x = np.ogrid[-radius:radius + 1, -radius:radius + 1]
    return x * x + y * y <= radius * radius


def largest(component_mask):
    labels, count = ndimage.label(component_mask)
    if count == 0:
        return component_mask
    sizes = ndimage.sum(component_mask, labels, range(1, count + 1))
    return labels == (np.argmax(sizes) + 1)


def drop_edge_pieces(mask, min_size):
    """칸 가장자리에 닿은 조각(옆 곰의 일부)과 너무 작은 티끌을 버린다."""
    labels, count = ndimage.label(mask)
    if count == 0:
        return mask
    sizes = ndimage.sum(mask, labels, range(1, count + 1))
    keep = np.isin(labels, np.flatnonzero(sizes >= min_size) + 1)
    edge = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    return keep & ~np.isin(labels, edge[edge > 0])


def extract(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    sat = rgb.max(axis=-1) - rgb.min(axis=-1)

    # 갈색 연필: 빨강이 파랑보다 크고(파랑 · 보라 · 초록 물감 제외), 빨강이 너무 밝지 않다(분홍 · 노랑 물감 제외).
    # 옅게 그은 'z'나 움직임 선도 갈색이므로 밝기 기준은 넉넉히 둔다.
    brownish = ((r - b) > 0.04) & ((g - b) > -0.02) & (r < 0.68)
    ink_alpha = np.clip((0.64 - lum) / 0.24, 0, 1) * brownish
    ink = drop_edge_pieces(ink_alpha > 0.35, 25)
    ink_alpha = ink_alpha * ndimage.binary_dilation(ink, iterations=2)

    # 실루엣: 바깥에서 흘려 넣은 물이 닿지 않는 곳. 손으로 그은 외곽선의 작은 틈은
    # 선을 잠깐 두껍게 해서 막고, 다 채운 뒤 그만큼 다시 깎는다.
    walls = ndimage.binary_dilation(ink, iterations=4)
    open_labels, _ = ndimage.label(~walls)
    border = np.unique(np.concatenate([open_labels[0], open_labels[-1], open_labels[:, 0], open_labels[:, -1]]))
    outside = np.isin(open_labels, border[border > 0])
    body = largest(ndimage.binary_fill_holes(~outside))
    silhouette = ndimage.binary_erosion(body, iterations=2)

    # 주둥이: 실루엣 안의 새하얀 종이 중에서 코와 입을 품고 있는 덩어리.
    # 옅은 물감 자리도 거의 흰색이라 주둥이와 가늘게 이어지곤 한다. 그래서 고른 덩어리를
    # 한 번 깎았다 불려(opening) 가는 다리를 끊고, 코가 있는 쪽만 남긴 뒤 코 둘레로 자른다.
    white = (lum > 0.955) & (sat < 0.06) & silhouette & ~ndimage.binary_dilation(ink, iterations=1)
    # 코와 입은 외곽선과 떨어진 작은 선 조각이다. 외곽선 일부가 흰 자리에 걸려 코로 잡히지 않도록
    # 작은 조각이 통째로 흰 자리 안에 들어 있을 때만 코로 센다.
    ink_labels, ink_count = ndimage.label(ink)
    ink_sizes = ndimage.sum(ink, ink_labels, range(1, ink_count + 1))
    small_ink = np.isin(ink_labels, np.flatnonzero(ink_sizes < silhouette.sum() * 0.01) + 1)

    labels, count = ndimage.label(white)
    best, best_nose, best_score = None, None, 0
    for index in range(1, count + 1):
        part = labels == index
        if part.sum() < 200:
            continue
        filled = ndimage.binary_fill_holes(ndimage.binary_closing(part, iterations=3))
        touched = np.unique(ink_labels[filled & small_ink])
        whole = [i for i in touched if i and not (ink_labels == i)[~filled].any()]
        nose = np.isin(ink_labels, whole)
        if nose.sum() > best_score:
            best, best_nose, best_score = filled, nose, nose.sum()
    muzzle = np.zeros_like(silhouette)
    if best is not None:
        radius = max(6, int(rgb.shape[1] * 0.007))
        opened = ndimage.binary_opening(best, structure=disk(radius))
        pieces, count = ndimage.label(opened)
        if count:
            overlap = ndimage.sum(ndimage.binary_dilation(best_nose, iterations=radius), pieces, range(1, count + 1))
            muzzle = ndimage.binary_fill_holes(pieces == (np.argmax(overlap) + 1))
            cy, cx = ndimage.center_of_mass(best_nose)
            reach = 1.3 * np.sqrt(muzzle.sum() / np.pi)
            yy, xx = np.ogrid[:muzzle.shape[0], :muzzle.shape[1]]
            muzzle &= (yy - cy) ** 2 + (xx - cx) ** 2 <= reach ** 2
    else:
        # 코가 흰 자리에 다 갇히지 않은 얼굴(도넛을 문 곰, 책에 코가 닿은 곰).
        # 작은 선 조각(코 · 입 · 눈)에 가장 많이 맞닿은 흰 덩어리를 주둥이로 본다.
        # 외곽선 옆 흰 틈은 큰 선에만 닿아 있어 걸리지 않는다.
        # 책의 흰 종이처럼 주둥이와 이어진 큰 흰 자리는 코 둘레 원으로 잘라 낸다.
        best_touch = 0
        reach = np.sqrt(silhouette.sum() * 0.012 / np.pi)
        yy, xx = np.ogrid[:silhouette.shape[0], :silhouette.shape[1]]
        for index in range(1, count + 1):
            part = labels == index
            if part.sum() < 200:
                continue
            touching = ndimage.binary_dilation(part, iterations=6) & small_ink
            if touching.sum() <= best_touch:
                continue
            best_touch = touching.sum()
            region = ndimage.binary_fill_holes(ndimage.binary_closing(part, iterations=3))
            if region.sum() > silhouette.sum() * 0.06:
                cy, cx = ndimage.center_of_mass(touching)
                region &= (yy - cy) ** 2 + (xx - cx) ** 2 <= reach ** 2
            muzzle = region
        if best_touch == 0:
            # 코마저 외곽선에 붙어 버린 얼굴(책 위로 내민 곰). 몸 안의 작은 선 조각 둘(눈)
            # 사이에서 가장 가까운 흰 덩어리를 주둥이로 본다.
            eyes = small_ink & silhouette
            if eyes.any():
                ey, ex = ndimage.center_of_mass(eyes)
                nearest = None
                for index in range(1, count + 1):
                    part = labels == index
                    if part.sum() < 200 or part.sum() > silhouette.sum() * 0.06:
                        continue
                    py, px = ndimage.center_of_mass(part)
                    distance = np.hypot(py - ey, px - ex)
                    if nearest is None or distance < nearest[0]:
                        nearest = (distance, part)
                if nearest:
                    muzzle = ndimage.binary_fill_holes(ndimage.binary_closing(nearest[1], iterations=3))

    # 소품: 몸 안에서 연필 선으로 둘러싸인 칸 중 파스텔 물감과 확연히 다른 칸.
    #  · 물감보다 훨씬 진한 색 — 책의 주황, 도넛의 분홍, 모자의 노랑.
    #    파스텔 물감 칸은 채도 중앙값이 0.2 아래라 걸리지 않는다(도넛 0.34, 몸 0.16).
    #  · 색이 없는 회색 · 검정 — 아령, 선글라스 렌즈.
    #  · 새하얀 종이 — 공책 속지.
    # 몸통 칸 자체가 걸리지 않도록 실루엣의 35%를 넘는 칸은 소품으로 보지 않는다.
    props = np.zeros_like(silhouette)
    cells, count = ndimage.label(silhouette & ~walls)
    for index in range(1, count + 1):
        cell = cells == index
        if not 150 <= cell.sum() <= silhouette.sum() * 0.35:
            continue
        cell_sat, cell_lum = np.median(sat[cell]), np.median(lum[cell])
        vivid = cell_sat > 0.28
        neutral = cell_sat < 0.1 and (cell_lum < 0.8 or cell_lum > 0.93)
        if vivid or neutral:
            props |= ndimage.binary_dilation(cell, iterations=5) & ~ink
    props &= silhouette

    # 몸 밖의 색 있는 표시: 종이보다 눈에 띄게 어둡거나 색이 있는 자리. 외곽선 바로 바깥은
    # 원화 물감이 선 밖으로 살짝 번진 자국이라 뺀다.
    marked = (lum < 0.9) | (sat > 0.14)
    marks = drop_edge_pieces(marked & ~ndimage.binary_dilation(body, iterations=8), 15)
    marks = ndimage.binary_dilation(marks, iterations=2) & ~ndimage.binary_dilation(body, iterations=6)
    mark_alpha = np.clip(np.maximum((0.97 - lum) / 0.25, (sat - 0.04) / 0.2), 0, 1) * marks

    return ink_alpha, silhouette, muzzle | props, mark_alpha, ink | marks


def save(name, array, catalog):
    folder = catalog / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    Image.fromarray(array).save(folder / f"{name}.png", optimize=True)
    (folder / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"{name}.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")


def main(source_dir):
    shutil.rmtree(CATALOG, ignore_errors=True)
    CATALOG.mkdir(parents=True)
    (CATALOG / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    grids = {}

    for pose, filename, box, erase in SOURCES:
        image = Image.open(source_dir / filename).convert("RGB")
        rgb = np.asarray(image, dtype=np.float32) / 255
        rgb = rgb.copy()
        for x0, y0, x1, y1 in erase:
            rgb[y0:y1, x0:x1] = 1
        if box:
            x0, y0, x1, y1 = box
            rgb = rgb[y0:y1, x0:x1]
        ink_alpha, silhouette, keep, mark_alpha, drawn = extract(rgb)

        # 곰과 몸 밖 표시를 모두 담는 정사각형으로 자른다. 자세끼리 크기를 맞추려고
        # 여백은 긴 변의 6%로 통일한다.
        ys, xs = np.nonzero(silhouette | drawn)
        cx, cy = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2
        side = max(xs.max() - xs.min(), ys.max() - ys.min()) * 1.12
        crop = (int(cx - side / 2), int(cy - side / 2), int(cx + side / 2), int(cy + side / 2))

        def layer(rgb_part, alpha):
            rgba = (np.dstack([rgb_part, alpha]) * 255).astype(np.uint8)
            return Image.fromarray(rgba).crop(crop).resize((SIZE, SIZE), Image.LANCZOS)

        soft = lambda mask, sigma: ndimage.gaussian_filter(mask.astype(np.float32), sigma)
        keep_alpha = np.maximum(soft(keep, 1.2), mark_alpha) * (1 - ink_alpha)

        ink_image = layer(rgb, ink_alpha)
        mask_image = layer(np.ones_like(rgb), soft(silhouette, 1.0))
        keep_image = layer(rgb, keep_alpha)

        title = pose.capitalize()
        save(f"BearInk{title}", np.asarray(ink_image), CATALOG)
        save(f"BearMask{title}", np.asarray(mask_image), CATALOG)
        save(f"BearKeep{title}", np.asarray(keep_image), CATALOG)

        alpha = np.asarray(mask_image)[..., 3].astype(np.float32) / 255
        cells = alpha.reshape(GRID, SIZE // GRID, GRID, SIZE // GRID).mean(axis=(1, 3))
        grids[pose] = ["".join("#" if value > 0.35 else "." for value in row) for row in cells]
        print(f"{pose}: silhouette {silhouette.sum()} px, keep {keep.sum()} px", file=sys.stderr)

    for pose, rows in grids.items():
        print(f"case .{pose}: [")
        for row in rows:
            print(f'    "{row}",')
        print("]")


if __name__ == "__main__":
    main(Path(sys.argv[1]).expanduser())
