"""Bake eight authored cloud contours and broad paint washes. Offline only.

Run with Python, Pillow, NumPy and SciPy (authoring tools, never game dependencies).
RGBA packs body light, highlight wash, lavender wash and signed edge distance.
The runtime reads this one 2048x512 atlas; it never generates image data.
"""
from pathlib import Path
import re

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import distance_transform_edt, gaussian_filter

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "ldjam_60/assets/sky/night_clouds.png"
W, H = 512, 256

# Individually drawn cubic contours, in a 500 x 250 painting space. Broken
# families contain separate islands; their gaps are part of the silhouette.
CONTOURS = [
    # Wide cumulus: raised left shoulder, shallow shelf, broken lower edge.
    "M 25 163 C 18 140 42 118 74 126 C 65 93 99 67 129 85 C 143 42 199 40 217 86 C 240 74 270 91 273 119 C 308 94 353 108 363 133 C 399 117 426 140 423 154 C 450 150 478 165 477 180 C 452 195 413 186 390 194 C 349 208 328 189 299 197 C 267 209 246 199 217 205 C 183 209 167 193 141 198 C 107 201 98 184 75 187 C 54 187 32 181 25 163 Z",
    # Broken shoal: three irregular islands, no connecting sausage.
    "M 20 141 C 22 120 43 111 62 116 C 56 83 97 66 116 86 C 129 47 183 60 184 105 C 220 91 246 121 234 143 C 213 158 176 155 158 163 C 119 177 103 155 77 162 C 51 161 24 158 20 141 Z M 272 172 C 263 155 277 135 298 139 C 299 112 337 104 349 132 C 368 119 396 144 389 162 C 409 160 424 176 413 185 C 390 197 352 183 334 190 C 307 195 281 188 272 172 Z M 441 114 C 435 98 451 85 464 93 C 477 88 489 99 482 111 C 472 119 453 119 441 114 Z",
    # Wind feather: lifted tip and carved underside, not an ellipse.
    "M 21 165 C 84 163 103 132 146 130 C 191 126 218 111 250 98 C 275 89 285 70 302 66 C 298 83 275 108 257 118 C 316 109 365 112 398 102 C 424 95 449 88 475 89 C 446 104 435 121 406 129 C 371 141 336 135 304 145 C 270 156 239 150 212 160 C 185 171 168 160 138 170 C 92 184 65 170 21 165 Z",
    # Billowing tower: a high asymmetric crown and small trailing fragments.
    "M 51 186 C 33 164 47 133 78 136 C 68 102 95 83 122 96 C 110 59 136 39 163 51 C 172 17 222 16 235 49 C 272 29 307 63 293 91 C 332 78 358 105 350 132 C 381 117 411 143 404 163 C 431 154 461 175 450 190 C 425 209 386 195 364 208 C 333 221 308 202 275 212 C 239 223 211 202 182 214 C 153 223 130 205 106 210 C 85 211 62 204 51 186 Z M 464 150 C 450 138 466 120 480 130 C 494 144 480 156 464 150 Z",
    # Small distant bank: low shoulder and compact uneven body.
    "M 91 161 C 83 144 99 127 124 130 C 120 100 151 86 175 101 C 189 68 232 76 242 103 C 271 85 309 101 309 124 C 339 111 373 137 364 157 C 387 160 402 175 391 183 C 366 195 339 183 314 191 C 278 201 262 187 235 193 C 208 199 191 183 168 189 C 142 193 110 182 91 161 Z",
    # Layered stratus: interleaved shelves and detached edges.
    "M 24 131 C 88 120 108 103 161 108 C 198 113 226 89 272 95 C 319 104 350 85 397 92 C 417 95 441 92 463 87 C 449 107 415 119 384 118 C 350 116 325 133 288 129 C 248 125 229 143 190 141 C 145 136 118 153 86 145 C 63 139 40 141 24 131 Z M 68 183 C 108 173 132 158 171 164 C 208 169 225 153 260 156 C 291 162 326 146 353 151 C 379 157 414 145 437 149 C 417 165 393 176 365 174 C 329 170 310 189 277 184 C 240 178 219 197 186 191 C 143 184 110 200 68 183 Z M 393 205 C 419 192 447 194 474 181 C 466 200 435 210 393 205 Z",
    # Swept anvil: broad upper sail, narrow foot, eroded left edge.
    "M 34 112 C 69 117 91 94 124 101 C 132 68 169 60 193 81 C 208 44 256 49 271 80 C 304 66 331 83 340 99 C 388 96 418 79 477 86 C 451 104 434 127 400 132 C 369 139 338 133 315 147 C 293 161 293 179 270 193 C 249 207 218 201 192 208 C 166 212 131 202 103 204 C 123 191 145 187 156 170 C 173 146 142 143 123 146 C 100 151 86 139 68 139 C 52 139 42 126 34 112 Z",
    # Split crescent: open bite, tall right crown, small left companion.
    "M 121 180 C 145 172 167 170 180 149 C 192 131 174 122 155 120 C 178 108 192 105 211 112 C 218 83 248 72 269 90 C 266 51 299 32 327 51 C 358 35 391 64 379 94 C 407 93 426 119 416 140 C 447 146 457 177 436 191 C 414 207 392 191 366 207 C 335 220 312 203 288 213 C 255 223 237 203 212 212 C 182 222 147 201 121 180 Z M 29 159 C 21 144 41 125 57 135 C 71 116 101 128 100 149 C 117 152 119 169 102 175 C 74 182 51 164 29 159 Z",
]


def polygons(path):
    tokens = re.findall(r"[MCLZ]|-?\d+(?:\.\d+)?", path)
    tokens = [t for t in tokens if t.strip()]
    index, points, current = 0, [], np.zeros(2)
    while index < len(tokens):
        op = tokens[index]
        index += 1
        if op == "Z":
            yield points
            points = []
            continue
        count = {"M": 2, "L": 2, "C": 6}[op]
        numbers = np.array([float(v) for v in tokens[index:index + count]]).reshape(-1, 2)
        index += count
        if op in ("M", "L"):
            current = numbers[0]
            points.append(tuple(current))
        else:
            start = current.copy()
            for t in np.linspace(0, 1, 28)[1:]:
                q = (1-t)**3*start + 3*(1-t)**2*t*numbers[0] + 3*(1-t)*t*t*numbers[1] + t**3*numbers[2]
                points.append(tuple(q))
            current = numbers[2]


def bake(index, contour):
    mask = Image.new("L", (W, H))
    draw = ImageDraw.Draw(mask)
    for points in polygons(contour):
        draw.polygon([(x * W / 500, y * H / 250) for x, y in points], fill=255)
    inside = np.asarray(mask) > 128
    distance = distance_transform_edt(inside) - distance_transform_edt(~inside)
    y, x = np.mgrid[:H, :W] / np.array([H, W])[:, None, None]
    rng = np.random.default_rng(60 + index)
    wash = gaussian_filter(rng.random((H, W)), 17)
    wash = (wash - wash.mean()) / max(wash.std(), 0.001)
    # Broad diagonal paint strokes. These are flattened internal washes, not
    # lighting on repeated spherical components. The underside stays grounded.
    stroke = y + 0.045 * np.sin(x * 13 + index) + 0.018 * np.sin(x * 27 - index)
    body = np.clip(0.91 - y * 0.78 + wash * 0.016, 0, 1)
    shelf = 0.5 + 0.5 * np.tanh((stroke - 0.55) / 0.027)
    body -= shelf * 0.18
    body -= np.exp(-((stroke - 0.69) / 0.055)**2) * (0.025 + 0.025 * np.sin(x * 11 + index))
    highlight = np.exp(-((stroke - 0.36) / 0.19)**2) * (0.65 + 0.18 * np.cos(x * 8 + index))
    highlight += np.exp(-((stroke - 0.49) / 0.045)**2) * (0.06 + 0.05 * np.sin(x * 15 + index))
    # The rim is subtle and interrupted, never a glowing outline.
    highlight += np.exp(-((distance - 5) / 9)**2) * np.clip(0.65 - y, 0, 0.5) * 0.26
    lavender = np.clip(0.36 + wash * 0.06 + np.sin(x * 5 + index) * 0.2, 0, 1)
    return np.uint8(np.clip(np.stack([body, highlight, lavender, 0.5 + distance / 24], axis=-1), 0, 1) * 255)


def main():
    atlas = np.zeros((H * 2, W * 4, 4), dtype=np.uint8)
    for index, contour in enumerate(CONTOURS):
        atlas[(index//4)*H:(index//4+1)*H, (index%4)*W:(index%4+1)*W] = bake(index, contour)
    DEST.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(atlas).save(DEST, optimize=True)
    print(DEST)


if __name__ == "__main__":
    main()
