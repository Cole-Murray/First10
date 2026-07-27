import Toybox.Graphics;
import Toybox.Lang;

// Shared visual language for First10: a warm-amber identity on true AMOLED
// black. Every view reads its colors and a few shared layout helpers from
// here instead of hard-coding Graphics.COLOR_* constants, so the palette
// only needs to be tuned in one place.
module Theme {

    // ---- palette (raw 0xRRGGBB - not limited to the named system colors) ----

    const BG as Number         = 0x000000; // true black; AMOLED pixels off
    const ACCENT as Number     = 0xFF8C1A; // brand amber
    const ACCENT_DIM as Number = 0xB35F0F; // muted amber, secondary accent use
    const GO as Number         = 0x2ECC71; // success / "ready" green
    const GO_DIM as Number     = 0x1E5631; // dim green fill behind the check icon
    const ALERT as Number      = 0xFF3B30; // alarm red ("GET UP!")
    const WARN as Number       = 0xFFD400; // caution yellow
    const WARN_DIM as Number   = 0x7A5E00; // dim yellow fill behind the "!" icon
    const TXT as Number        = 0xFFFFFF; // primary text
    const TXT2 as Number       = 0x9AA0A6; // secondary text
    const TXT_HINT as Number   = 0x5A5F66; // dim hint text
    const RING_TRACK as Number = 0x2A2D31; // faint progress-ring track

    // ---- ring color ramp: amber (low) -> yellow (mid) -> green (near pass) ----

    function ringColor(progress as Float) as Number {
        if (progress >= 0.9) {
            return GO;
        } else if (progress >= 0.5) {
            return WARN;
        }
        return ACCENT;
    }

    function difficultyColor(level as Number) as Number {
        if (level <= Difficulty.EASY) {
            return GO;
        } else if (level == Difficulty.MEDIUM) {
            return WARN;
        }
        return ALERT;
    }

    // ---- layout helpers shared across FR265 (416x416) and FR265S (360x360) ----

    const RING_INSET as Number = 10; // px between the ring and the screen edge

    // Pen width for the alarm ring, scaled off the ring radius so it reads as
    // "bold" on both device sizes without being hand-tuned per device.
    function ringPenWidth(radius as Number) as Number {
        var pw = (radius * 0.085).toNumber();
        if (pw < 12) {
            pw = 12;
        }
        if (pw > 18) {
            pw = 18;
        }
        return pw;
    }

    // Large built-in numeral font for the nap length / countdown / score. Falls
    // back to the smaller numeral face on narrow screens (e.g. FR265S) so it
    // never clips. This gives a premium "custom numeral" look with no font
    // asset pipeline.
    function bigNumberFont(widthPx as Number) as Graphics.FontDefinition {
        if (widthPx < 390) {
            return Graphics.FONT_NUMBER_MEDIUM;
        }
        return Graphics.FONT_NUMBER_HOT;
    }

    // Advances a top-anchored text cursor past one line drawn in `font`, plus
    // `gapPx` of breathing room. Lets views stack lines by each font's actual
    // measured glyph height instead of guessing fixed screen-height fractions
    // (which overlap whenever a font renders taller than the guess assumed).
    function stackY(dc as Graphics.Dc, y as Number or Float, font as Graphics.FontDefinition, gapPx as Number) as Float {
        return y + dc.getFontHeight(font) + gapPx;
    }
}
