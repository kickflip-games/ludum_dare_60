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
    # Broad cumulus: three unequal shoulders over a shallow, eroded shelf.
    "M 24 157 C 20 140 39 127 70 130 C 67 99 97 85 128 100 C 137 61 178 48 209 76 C 229 57 265 72 268 104 C 307 91 339 108 341 131 C 370 113 401 130 406 146 C 438 141 469 151 476 169 C 451 182 417 177 389 183 C 357 188 328 178 300 185 C 262 189 235 180 211 187 C 173 190 151 178 121 184 C 88 186 71 177 49 178 C 36 175 26 170 24 157 Z",
    # Broken cluster: a generous main mass, an offset shoal and a little remnant.
    "M 24 133 C 25 110 54 99 77 110 C 83 72 116 57 148 83 C 170 68 199 82 202 106 C 229 106 245 128 233 147 C 207 159 174 151 151 159 C 120 165 96 152 71 158 C 46 159 24 151 24 133 Z M 275 167 C 268 146 290 130 315 137 C 320 106 355 102 374 124 C 401 113 429 131 426 153 C 448 158 456 177 441 186 C 417 195 394 183 367 191 C 339 196 314 182 296 186 C 282 184 276 178 275 167 Z M 445 101 C 431 95 438 80 453 81 C 465 69 483 80 478 94 C 471 102 456 105 445 101 Z",
    # Soft wind feather. Rounded shoulders and a broad belly, no spear tips.
    "M 30 156 C 49 142 77 143 103 130 C 132 115 164 124 189 107 C 215 90 249 96 272 81 C 298 66 323 66 335 74 C 321 84 311 95 303 109 C 340 98 369 107 401 94 C 427 84 450 89 468 99 C 448 105 432 120 408 128 C 380 141 352 133 321 145 C 290 158 265 147 237 159 C 212 168 187 155 159 165 C 124 179 99 163 74 170 C 53 173 37 165 30 156 Z",
    # Asymmetric billow: large offset crown, low trailing shelf, grounded base.
    "M 30 176 C 20 153 42 134 73 139 C 65 105 90 88 119 97 C 124 58 157 35 193 55 C 212 18 265 23 280 60 C 319 41 354 64 353 94 C 385 94 405 117 396 143 C 426 136 456 151 466 174 C 455 195 421 197 391 190 C 361 201 333 190 306 198 C 272 207 239 194 208 202 C 174 207 151 193 123 200 C 97 204 77 191 58 194 C 44 193 33 187 30 176 Z",
    # Distant compact cloud, long low shoulder and one off-centre crown.
    "M 73 156 C 73 134 99 121 126 130 C 136 102 163 96 184 110 C 200 79 241 82 257 112 C 287 102 313 114 317 135 C 347 128 377 141 383 156 C 406 152 426 165 424 178 C 395 188 373 180 351 185 C 321 191 292 181 267 188 C 235 192 210 181 185 186 C 158 188 138 177 114 181 C 90 182 74 173 73 156 Z",
    # A connected stratus shelf with a lower brush of detached vapour. The
    # main body has real depth; two equal narrow parallel strips read as ribbons.
    "M 24 119 C 49 101 78 105 103 93 C 130 80 161 93 186 82 C 218 68 252 81 280 72 C 314 61 347 78 373 72 C 402 64 440 79 472 77 C 462 98 437 109 412 109 C 386 104 363 123 337 118 C 310 113 293 130 299 145 C 326 135 354 145 376 138 C 401 129 426 137 449 135 C 434 156 410 170 385 166 C 359 161 340 181 311 175 C 279 169 254 187 226 177 C 199 169 175 186 148 179 C 121 174 93 181 74 173 C 95 158 119 156 137 143 C 112 140 90 147 68 138 C 48 137 29 132 24 119 Z M 369 199 C 394 184 421 193 446 180 C 440 197 416 207 397 204 C 383 209 371 204 369 199 Z",
    # Swept anvil: broad shelf above a tapered, substantial lower mass.
    "M 29 120 C 49 104 75 115 99 103 C 120 90 148 95 163 80 C 183 55 220 54 242 75 C 275 59 307 77 316 100 C 350 94 379 106 406 94 C 432 85 455 90 477 87 C 459 110 435 127 405 128 C 374 128 352 143 326 147 C 306 153 303 181 282 193 C 260 205 232 196 209 205 C 178 215 154 200 127 204 C 103 207 82 195 64 193 C 87 185 102 172 111 157 C 117 142 102 137 82 141 C 61 140 40 135 29 120 Z",
    # Ragged altocumulus: two broad interlocking masses, shallow lower notches.
    "M 40 169 C 28 149 46 126 72 128 C 77 101 102 91 127 108 C 145 79 179 82 195 108 C 219 94 247 106 249 132 C 277 126 299 142 296 161 C 320 167 326 186 310 196 C 288 209 261 191 240 201 C 216 210 194 192 171 200 C 142 209 121 190 98 197 C 72 201 45 189 40 169 Z M 282 100 C 271 84 286 66 306 73 C 305 43 337 31 360 51 C 380 35 414 51 411 77 C 443 72 468 96 458 119 C 479 128 478 150 458 159 C 432 166 414 150 391 157 C 365 166 348 149 328 154 C 306 157 286 142 292 123 C 276 122 273 108 282 100 Z",
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
    # A few large brush washes follow each formation's unequal shoulders.
    # These are painted values inside one contour, not sphere-chain geometry.
    crowns = [(.38, .31), (.27, .32), (.60, .40), (.46, .24),
              (.44, .41), (.55, .34), (.43, .30), (.71, .29)]
    cx, cy = crowns[index]
    stroke = y + .025 * np.sin(x * 9 + index) + wash * .012
    light_wash = np.exp(-(((x-cx)/.24)**2 + ((y-cy)/.25)**2))
    trailing_wash = np.exp(-(((x-(cx+.25))/.25)**2 + ((y-(cy+.17))/.12)**2))
    body = .82 - y * .65 + wash * .026 + light_wash * .12
    shelf = .5 + .5 * np.tanh((stroke - .62) / .055)
    body -= shelf * .17
    body -= np.exp(-((stroke - .72) / .07)**2) * .035
    highlight = light_wash * .78 + trailing_wash * .26
    # One soft curved brush stroke breaks up the smooth gradient without
    # introducing speckle or a repeated chain of shaded balls.
    brush_y = cy + .20 + .035 * np.sin(x * 12 + index)
    brush_extent = np.exp(-((x - cx - .12) / .28)**4)
    highlight += np.exp(-((y-brush_y) / .04)**2) * brush_extent * .22
    body -= np.exp(-((y-brush_y-.09) / .055)**2) * brush_extent * .07
    # Interrupted, cool upper-edge light; edges retain a firm painted contour.
    highlight += np.exp(-((distance - 6) / 10)**2) * np.clip(.66-y, 0, .5) * .24
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
