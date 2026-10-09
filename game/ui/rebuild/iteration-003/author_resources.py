"""Regenerate iteration-003's simple, self-contained SVG art.

All output is confined to this folder so the entire experiment can be removed
as one directory.  The checked-in SVG files are deliberately readable sources.
"""
from pathlib import Path

ROOT = Path(__file__).parent
ASSETS = {
    "mouse-avatar.svg": '<svg width="160" height="160" viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg"><rect width="160" height="160" rx="80" fill="#1c2a31"/><circle cx="48" cy="48" r="28" fill="#a9c4c3"/><circle cx="112" cy="48" r="28" fill="#a9c4c3"/><ellipse cx="80" cy="94" rx="48" ry="42" fill="#e6eeee"/><circle cx="63" cy="86" r="5" fill="#172126"/><circle cx="97" cy="86" r="5" fill="#172126"/><circle cx="80" cy="100" r="5" fill="#d67b87"/></svg>',
    "course-cover.svg": '<svg width="360" height="220" viewBox="0 0 360 220" xmlns="http://www.w3.org/2000/svg"><rect width="360" height="220" fill="#101b20"/><path d="M0 190 L150 34 L208 34 L360 190" fill="#1d3840"/><path d="M35 220 L180 52 L325 220" fill="#284e57"/><path d="M214 0 L360 0 L360 115" fill="#42ced1"/><circle cx="180" cy="105" r="38" fill="none" stroke="#d5fbf8" stroke-width="3"/></svg>',
}
for name, body in ASSETS.items():
    (ROOT / name).write_text(body, encoding="utf-8")
