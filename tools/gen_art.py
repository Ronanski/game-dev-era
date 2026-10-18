#!/usr/bin/env python3
"""Generates anime-style character art as SVG.

Every character is described by a few parameters (hair style, colors,
outfit, weapon...) and drawn from shared parts: big shiny eyes, layered
hair with a highlight, cel shading and soft outlines.

    python3 tools/gen_art.py

writes art/characters/<id>.svg (full body, used in the world and battles)
and art/portraits/<id>.svg (bust, used in dialogue). Re-run it after
changing a character below; Godot re-imports the files automatically.
To use hand-drawn art instead, simply replace the SVG/PNG with your own.
"""
import os

OUT = "#2b1d24"
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art")


# --- color helpers -------------------------------------------------------------

def _rgb(c):
    c = c.lstrip("#")
    return [int(c[i:i + 2], 16) / 255 for i in (0, 2, 4)]


def _hex(rgb):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(v * 255))) for v in rgb)


def dark(c, f=0.75):
    return _hex([v * f for v in _rgb(c)])


def light(c, t=0.3):
    return _hex([v + (1 - v) * t for v in _rgb(c)])


# --- svg primitives --------------------------------------------------------------

def path(d, fill, stroke=OUT, sw=2.5, extra=""):
    st = f'stroke="{stroke}" stroke-width="{sw}"' if stroke else 'stroke="none"'
    return (f'<path d="{d}" fill="{fill}" {st} stroke-linejoin="round" '
            f'stroke-linecap="round" {extra}/>')


def line(d, color, sw, extra=""):
    return path(d, "none", color, sw, extra)


def ellipse(cx, cy, rx, ry, fill, stroke=OUT, sw=2.5, extra=""):
    st = f'stroke="{stroke}" stroke-width="{sw}"' if stroke else 'stroke="none"'
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{fill}" {st} {extra}/>'


def shadow(d, opacity=0.16):
    return path(d, "#000000", None, extra=f'opacity="{opacity}"')


def group(items, transform=""):
    t = f' transform="{transform}"' if transform else ""
    return f"<g{t}>" + "".join(items) + "</g>"


def mirror(items):
    return group(items, "translate(200,0) scale(-1,1)")


# --- face ------------------------------------------------------------------------

FACE = ("M46,86 C46,116 70,140 92,148 Q100,152 108,148 C130,140 154,116 154,86 "
        "C154,52 130,30 100,30 C70,30 46,52 46,86 Z")


def eye(cx, cy, iris, style, gid, flip):
    """One anime eye. flip=True for the viewer's right eye."""
    s = -1 if flip else 1
    out = []
    if style == "closed":
        return [line(f"M{cx - 11},{cy + 2} Q{cx},{cy - 9} {cx + 11},{cy + 2}", OUT, 3.2)]
    out.append(ellipse(cx, cy, 11, 13.5, "#ffffff", OUT, 1.6))
    out.append(ellipse(cx, cy + 1.5, 9, 12, f"url(#{gid})", dark(iris, 0.45), 1.2))
    out.append(path(f"M{cx - 10},{cy - 6} Q{cx},{cy - 13} {cx + 10},{cy - 6} Q{cx},{cy - 9} {cx - 10},{cy - 6} Z",
                    "#000000", None, 'opacity="0.25"'))
    if style == "slit":
        out.append(ellipse(cx, cy + 1.5, 1.8, 9, "#1a0a0a", None))
        out.append(ellipse(cx + 3 * s, cy - 4, 1.8, 1.8, "#fff3c0", None))
    else:
        out.append(ellipse(cx, cy + 2.5, 4.2, 6, "#1a1018", None))
        out.append(ellipse(cx + 3.5 * s, cy - 4.5, 3.4, 3.6, "#ffffff", None))
        out.append(ellipse(cx - 3 * s, cy + 6.5, 1.7, 1.7, "#ffffff", None))
    # Upper lashes with a flick at the outer corner.
    o = cx - 13 * s
    out.append(path(f"M{cx + 12 * s},{cy - 8} Q{cx},{cy - 17} {o},{cy - 8} L{o - 4 * s},{cy - 12} "
                    f"Q{cx},{cy - 21} {cx + 13 * s},{cy - 10} Z", OUT, OUT, 1.2))
    out.append(line(f"M{cx - 7},{cy + 14} Q{cx},{cy + 16} {cx + 7},{cy + 14}", OUT, 1.4, 'opacity="0.55"'))
    if style == "narrow":
        out.append(path(f"M{cx - 15},{cy - 20} L{cx + 15},{cy - 20} L{cx + 15},{cy - 1} "
                        f"Q{cx},{cy - 6} {cx - 15},{cy - 1} Z", "SKIN", None))
        out.append(line(f"M{cx - 13},{cy - 1} Q{cx},{cy - 6} {cx + 13},{cy - 1}", OUT, 3))
    return out


def brows(style, color):
    shapes = {
        "normal": ("M68,82 Q78,77 88,81", "M112,81 Q122,77 132,82"),
        "angry": ("M67,78 Q78,80 89,86", "M111,86 Q122,80 133,78"),
        "worried": ("M68,82 Q78,80 88,77", "M112,77 Q122,80 132,82"),
        "gentle": ("M68,84 Q78,79 88,83", "M112,83 Q122,79 132,84"),
    }
    a, b = shapes.get(style, shapes["normal"])
    return [line(a, color, 2.6), line(b, color, 2.6)]


def mouth(style):
    if style == "smile":
        return [line("M93,130 Q100,136 107,130", OUT, 2.2)]
    if style == "grin":
        return [path("M90,128 Q100,140 110,128 Q100,131 90,128 Z", "#8a2b3a", OUT, 1.8)]
    if style == "frown":
        return [line("M94,134 Q100,130 106,134", OUT, 2.2)]
    if style == "smirk":
        return [line("M93,132 Q102,134 108,128", OUT, 2.2)]
    if style == "fangs":
        return [path("M86,127 Q100,142 114,127 Q100,132 86,127 Z", "#5a1020", OUT, 1.8),
                path("M90,129 L93,136 L96,130 Z", "#ffffff", None),
                path("M110,129 L107,136 L104,130 Z", "#ffffff", None)]
    return [line("M95,132 L105,132", OUT, 2.2)]


# --- hair --------------------------------------------------------------------------

def back_hair(style, c):
    shapes = {
        "long": "M36,90 C34,40 68,18 100,18 C132,18 166,40 164,90 L172,206 Q152,220 136,208 "
                "Q118,222 100,210 Q82,222 64,208 Q48,220 28,206 Z",
        "wild": "M36,90 C30,30 70,10 100,14 C134,10 172,30 164,90 L184,150 L168,150 L180,206 "
                "L156,196 L150,226 L128,206 L112,230 L100,208 L86,230 L72,206 L50,226 L44,196 "
                "L20,206 L32,150 L16,150 Z",
        "short": "M38,94 C36,40 68,20 100,20 C132,20 164,40 162,94 L160,126 Q144,120 134,130 "
                 "L66,130 Q56,120 40,126 Z",
        "spiky": "M40,96 L22,74 L44,64 L28,40 L56,40 L52,16 L76,28 L86,2 L102,22 L120,4 L126,28 "
                 "L150,16 L146,40 L174,42 L156,64 L178,74 L160,96 L160,124 L40,124 Z",
        "bob": "M36,90 C34,40 68,18 100,18 C132,18 166,40 164,90 L166,150 Q152,158 138,148 "
               "L62,148 Q48,158 34,150 Z",
        "ponytail": "M38,94 C36,40 68,20 100,20 C132,20 164,40 162,94 L160,126 L40,126 Z",
        "bun": "M38,94 C36,40 68,20 100,20 C132,20 164,40 162,94 L160,126 L40,126 Z",
    }
    if style not in shapes:
        return []
    out = []
    if style == "ponytail":
        out.append(path("M140,52 Q192,58 182,140 Q176,186 192,214 Q150,204 152,150 "
                        "Q154,96 132,74 Z", c))
        out.append(path("M140,52 Q170,56 176,100 Q160,80 140,70 Z", dark(c), None))
    if style == "bun":
        out.append(ellipse(100, 22, 24, 20, c))
    out.append(path(shapes[style], c))
    return out


BANGS = {
    # (root x, root y), (tip x, tip y) pairs from right to left.
    "neat": [(140, 62), (130, 92), (118, 60), (106, 90), (96, 58), (84, 92), (72, 62), (62, 92)],
    "parted": [(140, 66), (128, 94), (118, 58), (108, 92), (100, 38), (92, 92), (82, 58), (72, 94), (60, 66)],
    "spiky": [(142, 58), (134, 98), (122, 54), (110, 94), (98, 52), (86, 98), (74, 54), (62, 94)],
    "swept": [(132, 54), (118, 80), (104, 50), (88, 74), (74, 52), (62, 82)],
    "short": [(136, 58), (124, 80), (112, 56), (100, 78), (88, 56), (76, 80), (64, 60)],
}


def bangs(style, c):
    if style not in BANGS:
        return []
    pts = BANGS[style]
    lock = 128 if style != "short" else 112
    d = f"M34,98 C30,38 66,18 100,18 C134,18 170,38 166,98 L162,{lock} Q158,110 150,92"
    px, py = 150, 92
    for i, (x, y) in enumerate(pts):
        if i % 2 == 1:
            y -= 7
        cx, cy = (px + x) / 2, (py + y) / 2 + 5
        d += f" Q{cx},{cy} {x},{y}"
        px, py = x, y
    d += f" Q{(px + 50) / 2},{(py + 92) / 2 + 5} 50,92 L38,{lock} Q36,110 34,98 Z"
    shine = light(c, 0.5)
    return [path(d, c),
            path("M56,52 Q64,42 76,38 Q74,44 66,52 Q60,56 56,52 Z", shine, None, 'opacity="0.75"'),
            path("M84,34 Q100,30 116,34 Q114,40 100,38 Q86,40 84,34 Z", shine, None, 'opacity="0.75"'),
            path("M124,38 Q136,42 144,52 Q140,56 134,52 Q126,44 124,38 Z", shine, None, 'opacity="0.75"'),
            line("M120,60 Q128,72 130,84 M80,60 Q72,72 70,84", dark(c, 0.7), 1.6, 'opacity="0.8"')]


# --- body ----------------------------------------------------------------------------

def arms(sleeve, skin, wide=False, metal=None):
    if wide:
        left = "M70,166 Q50,190 44,236 Q58,242 74,236 Q70,204 82,180 Z"
        hand = (60, 240)
    else:
        left = "M70,166 Q54,184 54,224 L68,226 Q68,198 80,180 Z"
        hand = (61, 230)
    fill = metal or sleeve
    side = [path(left, fill)]
    if wide:
        side.append(path("M44,236 Q58,242 74,236 L73,230 Q58,236 45,230 Z", dark(fill, 0.8), None))
    return side, hand


def legs(pants, boots):
    return [
        path("M76,212 L74,268 L96,268 L98,212 Z", pants),
        path("M102,212 L104,268 L126,268 L124,212 Z", pants),
        path("M72,262 L72,286 Q72,294 80,294 L100,294 Q102,286 96,284 L96,262 Z", boots),
        path("M104,262 L104,284 Q98,286 100,294 L120,294 Q128,294 128,286 L128,262 Z", boots),
        shadow("M114,212 L124,212 L126,268 L116,268 Z", 0.18),
    ]


def body(ch):
    """Returns the body (everything below the neck) as a list of svg strings."""
    o, a, skin = ch["o"], ch["a"], ch["skin"]
    boots = ch.get("boots", "#3b2a20")
    outfit = ch.get("outfit", "tunic")
    out = []
    wide = outfit in ("robe", "dress", "priest", "cloak")
    if outfit in ("tunic", "armor"):
        out += legs(ch.get("pants", dark(o, 0.6)), boots if outfit == "tunic" else dark(ch.get("w", "#9aa6b2"), 0.7))
    if outfit == "tunic":
        out.append(path("M64,170 Q66,158 100,156 Q134,158 136,170 L144,240 Q100,250 56,240 Z", o))
        out.append(shadow("M118,160 Q134,160 136,170 L144,240 Q132,244 124,244 Q130,200 118,160 Z"))
        out.append(path("M60,208 Q100,216 140,208 L141,219 Q100,227 59,219 Z", a))
        out.append(line("M88,158 L100,176 L112,158", a, 4))
    elif outfit == "armor":
        w = ch.get("w", "#9aa6b2")
        out.append(path("M56,204 L144,204 L150,246 Q100,256 50,246 Z", o))
        out.append(line("M78,210 L74,248 M100,210 L100,252 M122,210 L126,248", dark(o, 0.7), 2))
        out.append(path("M64,170 Q66,156 100,154 Q134,156 136,170 L138,212 Q100,222 62,212 Z", w))
        out.append(path("M76,168 Q90,162 98,164 L96,200 Q84,202 78,198 Z", "#ffffff", None, extra='opacity="0.35"'))
        out.append(shadow("M116,160 Q134,158 136,170 L138,212 Q126,216 118,216 Q124,190 116,160 Z", 0.2))
        out.append(line("M100,162 L100,214", dark(w, 0.7), 2))
        out.append(path("M60,206 Q100,214 140,206 L141,216 Q100,224 59,216 Z", a))
        out.append(ellipse(100, 211, 6, 5, light(a, 0.3), OUT, 1.5))
    else:
        if outfit == "tattered":
            hem = ("L156,286 L144,276 L134,292 L122,278 L110,294 L100,280 L90,294 L78,278 L66,292 "
                   "L56,276 L44,286 L58,214 Z")
        else:
            hem = "Q154,252 160,288 Q100,298 40,288 Q46,252 58,214 Z"
        if outfit not in ("tattered", "floating"):
            out.append(ellipse(84, 292, 11, 5, boots))
            out.append(ellipse(116, 292, 11, 5, boots))
        if outfit == "floating":
            out.append(path("M64,212 Q100,236 136,212 Q130,262 100,290 Q70,262 64,212 Z",
                            "url(#trail)", None))
            out.append(path("M64,170 Q66,158 100,156 Q134,158 136,170 L140,222 L130,232 L120,222 "
                            "L110,236 L100,224 L90,236 L80,222 L70,232 L60,222 Z", o))
        else:
            out.append(path(f"M64,170 Q66,158 100,156 Q134,158 136,170 L142,214 {hem}", o))
            out.append(shadow("M120,162 Q134,160 136,170 L142,214 Q154,252 160,288 Q146,292 132,292 "
                              "Q138,230 120,162 Z"))
        if outfit == "dress":
            out.append(path("M64,170 Q66,158 100,156 Q134,158 136,170 L139,206 Q100,214 61,206 Z", a))
            out.append(path("M42,282 Q100,292 158,282 L160,288 Q100,298 40,288 Z", light(o, 0.35), None))
        elif outfit == "priest":
            out.append(path("M84,160 L78,290 L90,291 L93,168 Z", a))
            out.append(path("M116,160 L122,290 L110,291 L107,168 Z", a))
            out.append(line("M88,170 Q100,188 112,170", "#c9d1d9", 1.6))
            out.append(ellipse(100, 190, 8, 8, "#e8eef8", OUT, 1.8))
            out.append(path("M98,183 A7,7 0 1,0 98,197 A5,5 0 1,1 98,183 Z", "#a8b8d8", None))
        elif outfit in ("robe", "cloak"):
            out.append(line("M100,176 L100,292", a, 5))
            out.append(path("M42,282 Q100,292 158,282 L160,288 Q100,298 40,288 Z", a))
        if outfit not in ("dress", "priest", "floating"):
            out.append(path("M60,206 Q100,214 140,206 L141,216 Q100,224 59,216 Z", a))
        if outfit != "priest":
            out.append(line("M88,158 L100,176 L112,158", a, 4))
        if ch.get("apron"):
            out.append(path("M76,214 L124,214 L134,280 Q100,288 66,280 Z", ch["apron"]))
    if outfit == "cloak":
        out.append(path("M62,166 Q100,150 138,166 L150,214 Q100,226 50,214 Z", dark(o, 0.85)))

    side, hand = arms(o, skin, wide, ch.get("w") if outfit == "armor" else None)
    if outfit == "dress":
        side.append(ellipse(70, 170, 14, 11, light(a, 0.2)))
    if outfit == "armor":
        side.append(ellipse(66, 170, 17, 13, ch.get("w", "#9aa6b2")))
        side.append(path("M54,166 Q62,160 72,162", "none", "#ffffff", 2.5, 'opacity="0.5"'))
    out += side
    out.append(mirror(side))
    out += weapon(ch.get("weapon"), a)
    out.append(ellipse(hand[0], hand[1], 8, 8, skin))
    out.append(ellipse(200 - hand[0], hand[1], 8, 8, skin))
    if ch.get("claws"):
        for hx in (hand[0], 200 - hand[0]):
            out.append(path(f"M{hx - 6},{hand[1] + 5} L{hx - 7},{hand[1] + 15} L{hx - 2},{hand[1] + 7} "
                            f"L{hx},{hand[1] + 17} L{hx + 3},{hand[1] + 7} L{hx + 7},{hand[1] + 15} "
                            f"L{hx + 6},{hand[1] + 5} Z", "#e8e0d0", OUT, 1.2))
    return out


def weapon(kind, accent):
    if kind == "staff":
        return [line("M152,104 L138,296", OUT, 9), line("M152,104 L138,296", "#8a5a34", 5),
                path("M154,82 A16,16 0 1,0 154,114 A12,12 0 1,1 154,82 Z", accent, OUT, 2),
                ellipse(150, 98, 4, 4, "#e8fbff", None, extra='opacity="0.9"')]
    if kind == "sword":
        return [path("M134,234 L150,298 L157,296 L143,232 Z", "#e2e8f0", OUT, 2),
                line("M139,238 L152,292", "#ffffff", 1.5, 'opacity="0.7"'),
                path("M126,230 L152,222 L154,229 L128,237 Z", accent, OUT, 2)]
    if kind == "spear":
        return [line("M152,64 L138,298", OUT, 8), line("M152,64 L138,298", "#8a5a34", 4),
                path("M150,34 L160,66 L146,68 Z", "#e2e8f0", OUT, 2)]
    if kind == "dagger":
        return [path("M134,236 L139,268 L146,236 Z", "#e2e8f0", OUT, 2),
                path("M130,232 L150,230 L150,236 L130,238 Z", accent, OUT, 1.5)]
    return []


# --- headgear & extras ---------------------------------------------------------

def headgear(kind, ch):
    a = ch["a"]
    if kind == "headband":
        return [path("M40,76 Q100,58 160,76 L159,85 Q100,68 41,85 Z", a),
                ellipse(100, 70, 6, 6, "#7fe0d8", OUT, 1.8)]
    if kind == "ornament":
        return [ellipse(150, 58, 9, 9, a), ellipse(160, 70, 6, 6, a), ellipse(146, 74, 5, 5, light(a, 0.3)),
                line("M150,58 L176,46", a, 3)]
    if kind == "putong":
        c = ch.get("cloth", "#8a1f1f")
        return [path("M36,80 Q34,46 60,32 Q100,14 140,32 Q166,46 164,80 Q100,56 36,80 Z", c),
                line("M46,64 Q100,40 154,64", a, 3),
                line("M52,50 Q100,30 148,50", dark(c, 0.7), 2),
                path("M156,52 Q186,60 184,96 Q172,76 158,70 Z", c)]
    if kind == "helmet":
        w = ch.get("hw", ch.get("w", "#9aa6b2"))
        return [path("M32,98 C28,34 66,12 100,12 C134,12 172,34 168,98 L158,100 Q154,72 100,70 "
                     "Q46,72 42,100 Z", w),
                path("M40,84 Q100,64 160,84 L160,92 Q100,72 40,92 Z", dark(w, 0.8), None),
                line("M100,14 L100,68", dark(w, 0.7), 3),
                path("M56,34 Q76,22 96,20 L94,40 Q74,40 60,48 Z", "#ffffff", None, 'opacity="0.35"'),
                path("M86,14 Q100,-2 114,14 L110,26 Q100,18 90,26 Z", a)]
    if kind == "hood":
        c = ch["o"]
        return [path("M40,106 Q34,36 100,24 Q166,36 160,106 Q154,58 100,46 Q46,58 40,106 Z", dark(c, 0.85))]
    if kind == "hat":
        c = ch.get("hat", "#c94f4f")
        return [path("M40,74 Q100,50 160,74 Q150,86 100,82 Q50,86 40,74 Z", dark(c, 0.8)),
                path("M54,70 Q70,30 98,6 Q112,-4 128,8 Q118,10 116,24 Q130,50 146,70 Q100,58 54,70 Z", c),
                line("M70,52 Q100,42 132,52", light(c, 0.3), 3, 'opacity="0.7"')]
    if kind == "bandana":
        c = ch.get("cloth", "#8a3a2a")
        return [path("M38,76 Q100,58 162,76 L161,86 Q100,70 39,86 Z", c),
                path("M160,78 Q182,82 186,104 Q170,94 160,88 Z", c)]
    return []


def beard(kind, c):
    if kind == "full":
        return [path("M54,112 Q58,176 100,192 Q142,176 146,112 Q130,144 100,146 Q70,144 54,112 Z", c),
                path("M84,128 Q100,120 116,128 Q100,134 84,128 Z", c)]
    if kind == "long":
        return [path("M58,118 Q60,200 100,234 Q140,200 142,118 Q126,146 100,148 Q74,146 58,118 Z", c),
                path("M82,128 Q100,118 118,128 Q100,136 82,128 Z", c),
                line("M100,150 L100,220 M88,152 L86,200 M112,152 L114,200", dark(c, 0.8), 1.6)]
    if kind == "stubble":
        return [path("M62,118 Q66,148 100,152 Q134,148 138,118 Q128,140 100,142 Q72,140 62,118 Z",
                     c, None, extra='opacity="0.55"')]
    if kind == "mustache":
        return [path("M82,128 Q92,120 100,126 Q108,120 118,128 Q110,134 100,130 Q90,134 82,128 Z", c)]
    return []


# --- characters ------------------------------------------------------------------

def defs(gid, iris, extra=""):
    return (f'<defs><linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{dark(iris, 0.35)}"/>'
            f'<stop offset="0.55" stop-color="{iris}"/>'
            f'<stop offset="1" stop-color="{light(iris, 0.45)}"/></linearGradient>'
            '<linearGradient id="trail" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#6a2a3a"/><stop offset="1" stop-color="#6a2a3a" stop-opacity="0"/>'
            f'</linearGradient>{extra}</defs>')


def face_parts(ch, gid):
    skin, hair = ch["skin"], ch["hair"]
    style = ch.get("eyes_style", "normal")
    out = [path(FACE, skin),
           shadow("M50,84 Q100,74 150,84 Q148,90 100,84 Q52,90 50,84 Z", 0.16),
           line("M99,118 L101,121", dark(skin, 0.6), 2)]
    if ch.get("blush", True):
        out += [ellipse(66, 122, 8, 4, "#ff7a8a", None, extra='opacity="0.35"'),
                ellipse(134, 122, 8, 4, "#ff7a8a", None, extra='opacity="0.35"')]
    for e in eye(78, 104, ch["eyes"], style, gid, False) + eye(122, 104, ch["eyes"], style, gid, True):
        out.append(e.replace('"SKIN"', f'"{skin}"'))
    out += mouth(ch.get("mouth", "neutral"))
    if ch.get("cigar"):
        out += [path("M108,131 L128,126 L129,132 L110,137 Z", "#6a4a2a", OUT, 1.5),
                ellipse(130, 129, 3.5, 3.5, "#ffb050", None),
                ellipse(130, 129, 7, 7, "#ff8a3a", None, extra='opacity="0.35"')]
    return out


def human(ch, cid):
    gid = "iris_" + cid
    hair = ch["hair"]
    back, front = [], []
    if ch.get("cape"):
        back.append(path("M72,160 L128,160 Q150,220 158,290 Q100,300 42,290 Q50,220 72,160 Z", ch["cape"]))
        back.append(shadow("M100,160 L128,160 Q150,220 158,290 Q130,296 110,296 Z", 0.2))
    if ch.get("wings"):
        wing = [path("M80,176 Q34,110 2,138 Q18,150 10,172 Q30,168 30,192 Q44,182 52,204 "
                     "Q62,184 82,192 Z", ch["wings"]),
                line("M78,180 L14,150 M76,184 L30,186 M78,188 L52,200", dark(ch["wings"], 0.7), 1.6)]
        back += wing + [mirror(wing)]
    if ch.get("hood"):
        back.append(path("M28,116 Q22,30 100,12 Q178,30 172,116 L162,160 L38,160 Z", dark(ch["o"], 0.8)))
    back += back_hair(ch.get("hair_style", "short"), hair)

    size = ch.get("size", "normal")
    btrans = ""
    if size == "big":
        btrans = "translate(100,158) scale(1.32,1.02) translate(-100,-158)"
    elif size == "small":
        btrans = "translate(100,158) scale(0.86,0.62) translate(-100,-158)"
    neck = [path("M90,138 L90,164 L110,164 L110,138 Z", ch["skin"]),
            shadow("M90,138 L110,138 L110,150 Q100,156 90,150 Z", 0.25)]

    if ch.get("head") == "horse":
        face = horse_head(ch, gid)
    else:
        face = face_parts(ch, gid)
        face += beard(ch.get("beard"), ch.get("beard_color", hair))
        front += bangs(ch.get("bangs", "neat"), hair)
        front += brows(ch.get("brows", "normal"), dark(hair, 0.6))
    front += headgear(ch.get("headgear"), ch)
    if ch.get("headgear") == "bandana":
        front.append(path("M50,112 Q100,128 150,112 L146,140 Q100,162 54,140 Z", ch.get("cloth", "#8a3a2a")))

    items = back + [group(body(ch), btrans)] + neck + face + front
    figure = "".join(items)
    if size == "small":
        figure = group([figure], "translate(0,54)")
    elif ch.get("float"):
        figure = group([figure], "translate(0,-8)")
    return defs(gid, ch["eyes"]) + figure


def horse_head(ch, gid):
    skin, hair = ch["skin"], ch["hair"]
    ear = [path("M72,48 L62,8 L90,36 Z", skin), path("M72,42 L67,18 L84,36 Z", dark(skin, 0.7), None)]
    out = [path("M84,24 Q104,4 128,22 Q156,34 164,76 Q168,116 182,156 Q152,136 148,104 "
                "Q142,64 120,44 Z", hair)]
    out += ear + [mirror(ear)]
    out += [path("M64,50 Q100,24 136,50 Q146,84 142,120 Q140,164 116,174 Q100,180 84,174 "
                 "Q60,164 58,120 Q54,84 64,50 Z", skin),
            shadow("M118,40 Q140,52 142,120 Q140,164 116,174 Q130,120 118,40 Z", 0.18),
            ellipse(100, 150, 32, 24, light(skin, 0.25)),
            ellipse(90, 152, 4, 6, OUT, None), ellipse(110, 152, 4, 6, OUT, None),
            line("M86,166 Q100,172 114,166", OUT, 2),
            path("M84,30 Q100,18 118,30 Q114,56 106,72 Q100,54 94,66 Q90,46 84,30 Z", hair)]
    for e in eye(80, 96, ch["eyes"], "normal", gid, False) + eye(120, 96, ch["eyes"], "normal", gid, True):
        out.append(e)
    out += [line("M68,76 Q80,80 90,86", dark(hair, 0.6), 3), line("M110,86 Q120,80 132,76", dark(hair, 0.6), 3)]
    out += [path("M116,160 L140,154 L141,160 L118,166 Z", "#6a4a2a", OUT, 1.5),
            ellipse(142, 157, 3.5, 3.5, "#ffb050", None),
            ellipse(142, 157, 8, 8, "#ff8a3a", None, extra='opacity="0.35"')]
    return out


def sigbin(ch, cid):
    gid = "iris_" + cid
    c, belly = ch["o"], light(ch["o"], 0.25)
    leg = [path("M64,232 Q40,258 50,294 L72,294 Q66,268 82,252 Z", dark(c, 0.85))]
    ear = [path("M70,140 Q30,108 30,72 Q58,102 86,128 Z", c), path("M68,132 Q44,110 40,88 Q60,108 80,126 Z",
                                                                   "#c06a7a", None)]
    out = [path("M146,222 Q192,206 186,150 Q184,126 198,114 Q176,120 174,150 Q176,192 140,204 Z", c),
           path("M60,206 L66,182 L76,198 L86,172 L96,194 L106,168 L114,192 L126,174 L132,196 L144,180 "
                "L146,210 Z", dark(c, 0.7))]
    out += leg + [mirror(leg)]
    out += [ellipse(100, 228, 62, 44, c), ellipse(100, 244, 38, 24, belly, None),
            shadow("M120,190 Q162,206 160,232 Q150,264 110,272 Q150,230 120,190 Z", 0.2)]
    out += ear + [mirror(ear)]
    out += [ellipse(100, 160, 46, 40, c),
            shadow("M118,124 Q146,140 144,170 Q136,196 104,200 Q136,170 118,124 Z", 0.2)]
    for e in eye(82, 156, ch["eyes"], "slit", gid, False) + eye(118, 156, ch["eyes"], "slit", gid, True):
        out.append(e)
    out += [line("M68,136 Q80,140 92,148", OUT, 3), line("M108,148 Q120,140 132,136", OUT, 3),
            path("M74,180 Q100,200 126,180 Q100,188 74,180 Z", "#3a0a14", OUT, 2),
            path("M78,182 L82,190 L86,184 L90,193 L95,185 L100,195 L105,185 L110,193 L114,184 L118,190 "
                 "L122,182 Q100,188 78,182 Z", "#ffffff", None)]
    return defs(gid, ch["eyes"]) + "".join(out)


# Character list. Colors: skin, hair, eyes (iris), o (outfit), a (accent),
# w (metal), boots, cape.
C = {
    "amihan": dict(skin="#f0c49c", hair="#2a2850", eyes="#2fb3a8", hair_style="long", bangs="parted",
                   outfit="robe", o="#2f7f86", a="#f2d36b", boots="#3b2a20", headgear="headband",
                   weapon="staff", mouth="smile"),
    "bagwis": dict(skin="#d69a6a", hair="#3a2418", eyes="#c98a2a", hair_style="spiky", bangs="spiky",
                   outfit="armor", w="#aab4c0", o="#7a2e2e", a="#d9a441", cape="#8a2a2a",
                   weapon="sword", brows="angry", blush=False),
    "tala": dict(skin="#f0c09a", hair="#a4442a", eyes="#e09a2a", hair_style="ponytail", bangs="neat",
                 outfit="tunic", o="#463c6e", a="#d94f4f", pants="#2a2440", boots="#3a2a30",
                 weapon="dagger", mouth="grin"),
    "gaspar": dict(skin="#f0c8a4", hair="#d8c8a0", eyes="#4a7ac8", hair_style="short", bangs="swept",
                   outfit="armor", w="#dce4ec", o="#2d4a8a", a="#f0d27a", cape="#2d4a8a",
                   weapon="sword", beard="stubble", beard_color="#a88868", brows="worried", blush=False),
    "hiraya": dict(skin="#e8b48a", hair="#16101c", eyes="#8a4a2a", hair_style="long", bangs="parted",
                   outfit="dress", o="#a8323e", a="#f6e6c8", headgear="ornament", mouth="frown",
                   brows="worried"),
    "banal": dict(skin="#e0aa80", hair="#e8e8ee", eyes="#7a8ab8", hair_style="long", bangs="swept",
                  outfit="priest", o="#f0eee6", a="#5a78b8", eyes_style="closed", mouth="smile",
                  beard="long", brows="gentle", blush=False),
    "dumalaw": dict(skin="#c88a5a", hair="#1a1010", eyes="#6a3a1a", hair_style="short", bangs="short",
                    outfit="tunic", o="#8a1f1f", a="#f0b53c", pants="#3a1a10", headgear="putong",
                    cloth="#a82a2a", beard="full", brows="angry", blush=False, mouth="frown"),
    "rosing": dict(skin="#e8b890", hair="#5a3824", eyes="#6a8a3a", hair_style="bun", bangs="neat",
                   outfit="robe", o="#6a8a4a", a="#e8d8b0", apron="#f4ecd8", mouth="smile"),
    "pacing": dict(skin="#e0aa80", hair="#2a1a10", eyes="#5a6aa8", hair_style="bob", bangs="neat",
                   outfit="robe", o="#5a7aa0", a="#e8d8b0", brows="worried"),
    "pepe": dict(skin="#e8b890", hair="#2a1a10", eyes="#6a4a2a", hair_style="spiky", bangs="spiky",
                 outfit="tunic", o="#c9a25a", a="#3a6a3a", pants="#5a4a2a", size="small", mouth="grin"),
    "lito": dict(skin="#d09868", hair="#2a1a10", eyes="#5a3a1a", hair_style="short", bangs="short",
                 outfit="tunic", o="#8a1f1f", a="#c9a25a", pants="#3a2a20", headgear="helmet",
                 hw="#8a6a4a", weapon="spear", brows="worried", blush=False),
    "ambo": dict(skin="#d8a070", hair="#8a8a8a", eyes="#5a4a3a", hair_style="short", bangs="short",
                 outfit="tunic", o="#a0784a", a="#5a3a2a", pants="#4a3a2a", beard="mustache",
                 eyes_style="narrow", mouth="smile", blush=False),
    "villager_a": dict(skin="#d09868", hair="#2a1a10", eyes="#5a3a1a", hair_style="short", bangs="neat",
                       outfit="tunic", o="#6a8a5a", a="#d9c9a3", pants="#4a3a2a"),
    "villager_b": dict(skin="#c88a5a", hair="#c0c0c8", eyes="#6a5a8a", hair_style="bun", bangs="neat",
                       outfit="robe", o="#7a5a8a", a="#d9c9a3", eyes_style="narrow", blush=False),
    "kabalyero": dict(skin="#f0c8a4", hair="#6a4a2a", eyes="#4a6a9a", hair_style="short", bangs="short",
                      outfit="armor", w="#c0cad4", o="#2d4a8a", a="#c0cad4", headgear="helmet",
                      weapon="spear", brows="angry", blush=False),
    "manlalakbay": dict(skin="#c88a5a", hair="#5a5048", eyes="#8a7a5a", hair_style="short", bangs="neat",
                        outfit="cloak", o="#6a6258", a="#a0784a", hood=True, headgear="hood",
                        eyes_style="narrow", blush=False),
    "tikbalang": dict(skin="#8a5a34", hair="#1a120c", eyes="#ffcc44", head="horse", outfit="tunic",
                      o="#3a2a1a", a="#c9a25a", pants="#2a1a10", boots="#1a1010", size="big"),
    "kapre": dict(skin="#5a3a28", hair="#141010", eyes="#ffdd55", hair_style="wild", bangs="spiky",
                  outfit="tunic", o="#2a3a2a", a="#6a4a2a", pants="#1a2a1a", boots="#1a1414",
                  size="big", beard="full", cigar=True, brows="angry", mouth="smirk", blush=False),
    "aswang": dict(skin="#b8b0c4", hair="#2a2a38", eyes="#ff4040", hair_style="wild", bangs="spiky",
                   outfit="tattered", o="#3a3a4a", a="#5a2a3a", eyes_style="slit", mouth="fangs",
                   brows="angry", claws=True, blush=False),
    "duwende": dict(skin="#d8a070", hair="#f0f0f0", eyes="#5a4a3a", hair_style="short", bangs="short",
                    outfit="tunic", o="#4a6a3a", a="#c9a25a", pants="#3a2a20", size="small",
                    headgear="hat", hat="#c94f4f", beard="long", eyes_style="narrow", mouth="smirk",
                    blush=False),
    "manananggal": dict(skin="#c8b8c8", hair="#101018", eyes="#ff5050", hair_style="long", bangs="parted",
                        outfit="floating", o="#6a2a3a", a="#3a1a24", wings="#3a2a3a", eyes_style="slit",
                        mouth="fangs", brows="angry", claws=True, float=True, blush=False),
    "bandido": dict(skin="#c88a5a", hair="#2a2020", eyes="#8a3a2a", hair_style="spiky", bangs="spiky",
                    outfit="tunic", o="#5a4a3a", a="#8a3a2a", pants="#3a2a20", headgear="bandana",
                    cloth="#7a2a2a", weapon="dagger", brows="angry", blush=False),
    "sigbin": dict(kind="sigbin", o="#4a3448", eyes="#ff3a3a"),
}


def sparkle():
    """Glowing marker for things you can inspect."""
    star = ("M100,150 Q108,206 160,214 Q108,222 100,278 Q92,222 40,214 Q92,206 100,150 Z")
    small = "M150,150 Q153,170 170,172 Q153,174 150,194 Q147,174 130,172 Q147,170 150,150 Z"
    return ('<defs><radialGradient id="glow"><stop offset="0" stop-color="#fff6c0" stop-opacity="0.9"/>'
            '<stop offset="1" stop-color="#ffd86a" stop-opacity="0"/></radialGradient></defs>'
            + ellipse(100, 214, 70, 70, "url(#glow)", None)
            + path(star, "#fff8d8", "#e8b84a", 3) + path(small, "#ffffff", "#e8b84a", 2))


def svg(content, view, width, height):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
            f'viewBox="{view}">{content}</svg>\n')


def main():
    os.makedirs(os.path.join(ROOT, "characters"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "portraits"), exist_ok=True)
    for cid, ch in C.items():
        content = sigbin(ch, cid) if ch.get("kind") == "sigbin" else human(ch, cid)
        with open(os.path.join(ROOT, "characters", cid + ".svg"), "w") as f:
            f.write(svg(content, "0 0 200 300", 400, 600))
        top = 100 if ch.get("kind") == "sigbin" else (70 if ch.get("size") == "small" else 4)
        with open(os.path.join(ROOT, "portraits", cid + ".svg"), "w") as f:
            f.write(svg(content, f"20 {top} 160 160", 480, 480))
    with open(os.path.join(ROOT, "characters", "sparkle.svg"), "w") as f:
        f.write(svg(sparkle(), "0 0 200 300", 400, 600))
    print("wrote %d characters to %s" % (len(C), os.path.normpath(ROOT)))


if __name__ == "__main__":
    main()
