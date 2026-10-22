#!/usr/bin/env python3
"""Generates the Streaks flame-'S' icon as SVG.

The icon is a thick flowing 'S' ribbon with two flame tongues rising from its
terminals.

Two techniques keep it looking like a single piece of fire:

1. The flame is drawn as ONE masked fill. The ribbon and the tongues live in
   an alpha mask and the gradient is painted through that mask, so the union
   has a single clean edge instead of the antialiasing seams that overlapping
   filled shapes leave behind.

2. The gradient uses gradientUnits="userSpaceOnUse", so every part of the
   flame takes its colour from its position on the canvas rather than from its
   own bounding box.
"""

import os

SIZE = 1024
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")

# The S: a flowing ribbon, drawn as a stroke so the terminals are round.
S_PATH = (
    "M 700 392 "
    "C 700 302 630 255 520 255 "
    "C 410 255 340 305 340 395 "
    "C 340 500 440 545 520 560 "
    "C 605 576 684 615 684 720 "
    "C 684 810 605 870 500 870 "
    "C 395 870 330 820 330 735"
)
S_WIDTH = 132

# Flame tongue rising from the top-right terminal of the S, as cubic segments:
# a start point followed by (c1, c2, end) triples.
TOP_TONGUE = [
    (694, 330),
    (700, 240), (726, 180), (768, 120),
    (812, 200), (806, 300), (772, 360),
    (752, 396), (712, 386), (694, 330),
]

# Flame tongue dropping from the bottom-left terminal of the S. Its base is
# buried inside the round cap of the stroke, so the two merge seamlessly, and
# it tapers to a point down and to the left.
BOTTOM_TONGUE = [
    (300, 700),
    (258, 760), (216, 826), (220, 900),
    (266, 880), (296, 826), (308, 766),
    (314, 726), (310, 706), (300, 700),
]


def path_d(pts):
    """Builds a closed cubic path from a flat list of (x, y) points."""
    out = [f"M {pts[0][0]:.0f} {pts[0][1]:.0f}"]
    for i in range(1, len(pts), 3):
        c1, c2, end = pts[i], pts[i + 1], pts[i + 2]
        out.append(
            f"C {c1[0]:.0f} {c1[1]:.0f} {c2[0]:.0f} {c2[1]:.0f} "
            f"{end[0]:.0f} {end[1]:.0f}"
        )
    return " ".join(out) + " Z"


def flame_mask():
    """The alpha mask holding the union of ribbon + tongues."""
    return f"""  <mask id="flameMask">
    <g fill="#ffffff" stroke="#ffffff" stroke-width="{S_WIDTH}"
       stroke-linecap="round" stroke-linejoin="round">
      <path d="{path_d(TOP_TONGUE)}" stroke="none"/>
      <path d="{path_d(BOTTOM_TONGUE)}" stroke="none"/>
      <path d="{S_PATH}" fill="none"/>
    </g>
  </mask>"""


GRADIENT = """    <linearGradient id="flame" gradientUnits="userSpaceOnUse" x1="0" y1="120" x2="0" y2="960">
      <stop offset="0%" stop-color="#FFD54A"/>
      <stop offset="45%" stop-color="#F79009"/>
      <stop offset="100%" stop-color="#D92D20"/>
    </linearGradient>"""

BG_DEFS = """    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FFFBF2"/>
      <stop offset="100%" stop-color="#F3E7D3"/>
    </linearGradient>
    <radialGradient id="glow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#F79009" stop-opacity="0.26"/>
      <stop offset="100%" stop-color="#F79009" stop-opacity="0"/>
    </radialGradient>"""


def flame_fill(scale=1.0):
    """Paints the flame gradient through the mask, optionally scaled."""
    transform = ""
    if scale != 1.0:
        transform = (
            f' transform="translate(512 512) scale({scale}) translate(-512 -512)"'
        )
    return f"""  <g{transform}>
    <rect width="{SIZE}" height="{SIZE}" fill="url(#flame)" mask="url(#flameMask)"/>
  </g>"""


def write_svg(name, body):
    path = os.path.join(OUT_DIR, name)
    with open(path, "w") as fh:
        fh.write(
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" '
            f'viewBox="0 0 {SIZE} {SIZE}">\n{body}\n</svg>\n'
        )
    print("wrote", os.path.abspath(path))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    # 1. full icon: cream squircle background + flame
    write_svg(
        "app_icon.svg",
        f"""  <defs>
{GRADIENT}
{BG_DEFS}
{flame_mask()}
  </defs>
  <rect width="{SIZE}" height="{SIZE}" rx="220" fill="url(#bg)"/>
  <circle cx="512" cy="540" r="430" fill="url(#glow)"/>
{flame_fill()}""",
    )

    # 2. round variant for legacy round launchers
    write_svg(
        "app_icon_round.svg",
        f"""  <defs>
{GRADIENT}
{BG_DEFS}
{flame_mask()}
  </defs>
  <circle cx="512" cy="512" r="512" fill="url(#bg)"/>
  <circle cx="512" cy="540" r="430" fill="url(#glow)"/>
{flame_fill()}""",
    )

    # 3. adaptive foreground: flame only, inside the 66% safe zone
    write_svg(
        "app_icon_foreground.svg",
        f"""  <defs>
{GRADIENT}
{flame_mask()}
  </defs>
{flame_fill(scale=0.58)}""",
    )

    # 4. monochrome layer for themed icons: the flame as a flat silhouette
    write_svg(
        "app_icon_monochrome.svg",
        f"""  <defs>
{flame_mask()}
  </defs>
  <g fill="#000000">
    <rect width="{SIZE}" height="{SIZE}" mask="url(#flameMask)"/>
  </g>""",
    )


if __name__ == "__main__":
    main()
