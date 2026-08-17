#!/usr/bin/env python3
"""Render a filled loop pack (contract + ledger + tick prompt) to one HTML review page.

Deterministic, dependency-free: a script render can never drift from the files,
unlike a model-written summary. The markdown stays the editable source of truth —
review in HTML, edit in .md, re-render.

Usage: python3 render_pack.py LOOP-CONTRACT.md LOOP-LEDGER.md LOOP-PROMPT.md [-o pack-review.html]
"""
import argparse
import datetime
import html
import pathlib
import re
import sys

# ledger/tick states -> semantic color class
STATE_CLASSES = {
    "landed": "good", "ready-to-land": "good", "SUCCESS": "good", "PROGRESS": "good",
    "landed-provisional": "warn", "ready-to-merge": "warn", "done-awaiting-gate": "warn",
    "done-reported": "warn", "WAITING": "warn", "HUMAN-GATE": "warn", "unclaimed": "warn",
    "in-flight": "info", "dispatching": "info", "eligible": "info", "claimed": "info",
    "blocked": "crit", "stale": "crit", "quarantined": "crit",
    "BLOCKED": "crit", "BUDGET": "crit", "NO-PROGRESS": "crit",
}
_STATE_RE = re.compile(r"\b(" + "|".join(sorted(map(re.escape, STATE_CLASSES), key=len, reverse=True)) + r")\b")


def inline(text: str) -> str:
    """Escape, then apply the inline markdown subset the templates use."""
    out = html.escape(text, quote=False)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    out = _STATE_RE.sub(lambda m: f'<span class="st st-{STATE_CLASSES[m.group(1)]}">{m.group(1)}</span>', out)
    return out


def render_md(text: str) -> str:
    """Convert the markdown subset used by the pack templates to HTML."""
    out, table, ul, code = [], [], False, False

    def flush_table():
        nonlocal table
        if not table:
            return
        rows = ['<div class="tablewrap"><table>']
        for i, cells in enumerate(table):
            tag = "th" if i == 0 else "td"
            rows.append("<tr>" + "".join(f"<{tag}>{inline(c)}</{tag}>" for c in cells) + "</tr>")
        rows.append("</table></div>")
        out.append("\n".join(rows))
        table = []

    def close_ul():
        nonlocal ul
        if ul:
            out.append("</ul>")
            ul = False

    for line in text.splitlines():
        if line.startswith("```"):
            flush_table(); close_ul()
            out.append("</code></pre>" if code else "<pre><code>")
            code = not code
            continue
        if code:
            out.append(html.escape(line, quote=False))
            continue
        s = line.strip()
        if s.startswith("|"):
            close_ul()
            cells = [c.strip() for c in s.strip("|").split("|")]
            if not all(re.fullmatch(r":?-{3,}:?", c) for c in cells):  # skip separator rows
                table.append(cells)
            continue
        flush_table()
        m = re.match(r"^(#{1,3})\s+(.*)$", s)
        if m:
            close_ul()
            lvl = len(m.group(1)) + 1  # page h1 is ours; file headings start at h2
            out.append(f"<h{lvl}>{inline(m.group(2))}</h{lvl}>")
            continue
        m = re.match(r"^-\s+\[([ xX])\]\s+(.*)$", s)
        if m:
            if not ul:
                out.append("<ul>"); ul = True
            box = "☑" if m.group(1) in "xX" else "☐"
            out.append(f'<li class="check">{box} {inline(m.group(2))}</li>')
            continue
        if s.startswith("- "):
            if not ul:
                out.append("<ul>"); ul = True
            out.append(f"<li>{inline(s[2:])}</li>")
            continue
        close_ul()
        if not s:
            continue
        out.append(f"<p>{inline(s)}</p>")
    flush_table(); close_ul()
    if code:
        out.append("</code></pre>")
    return "\n".join(out)


CSS = """
:root { --paper:#FBFBF9; --ink:#22302F; --muted:#5C6B69; --line:#E3E7E4; --acc:#0F7B7A;
  --acc-soft:#E3F0EF; --card:#FFFFFF; --code:#F2F4F2;
  --good:#2F7D46; --good-s:#E4F0E7; --warn:#A96A0B; --warn-s:#F7EEDC;
  --crit:#B3362B; --crit-s:#F8E7E4; --info:#0F7B7A; --info-s:#E3F0EF; }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --paper:#131817; --ink:#E6ECE9; --muted:#9AA8A4; --line:#2A3230; --acc:#45B8B5;
  --acc-soft:#16302F; --card:#181E1C; --code:#1B2220;
  --good:#6FBF87; --good-s:#17281C; --warn:#E0A64E; --warn-s:#2E2410;
  --crit:#E2766A; --crit-s:#321713; --info:#45B8B5; --info-s:#16302F; } }
:root[data-theme="dark"] {
  --paper:#131817; --ink:#E6ECE9; --muted:#9AA8A4; --line:#2A3230; --acc:#45B8B5;
  --acc-soft:#16302F; --card:#181E1C; --code:#1B2220;
  --good:#6FBF87; --good-s:#17281C; --warn:#E0A64E; --warn-s:#2E2410;
  --crit:#E2766A; --crit-s:#321713; --info:#45B8B5; --info-s:#16302F; }
* { box-sizing: border-box; }
body { margin:0; background:var(--paper); color:var(--ink); font:17px/1.6 Charter, Georgia, serif; }
.wrap { max-width: 920px; margin:0 auto; padding: 32px 24px 80px; }
h1,h2,h3,h4,nav,th { font-family:"Avenir Next", Seravek, "Segoe UI", ui-sans-serif, system-ui, sans-serif; }
h1 { font-size:1.7rem; margin:8px 0 4px; } h2 { font-size:1.25rem; margin:34px 0 10px; color:var(--acc); }
h3 { font-size:1.02rem; margin:22px 0 8px; } h4 { font-size:0.95rem; margin:18px 0 6px; }
p { margin:0 0 10px; max-width:75ch; } ul { margin:0 0 12px; padding-left:24px; } li { margin-bottom:4px; }
li.check { list-style:none; margin-left:-20px; }
nav { position:sticky; top:0; background:var(--paper); border-bottom:1px solid var(--line);
  padding:10px 0; display:flex; gap:14px; font-size:0.85rem; font-weight:600; z-index:2; }
nav a { color:var(--acc); text-decoration:none; } nav a:hover { text-decoration:underline; }
nav .tag { color:var(--muted); font-weight:400; margin-left:auto; }
section.file { background:var(--card); border:1px solid var(--line); border-radius:12px;
  padding:20px 24px; margin:22px 0; }
section.file > .path { font:0.75rem ui-monospace, Menlo, monospace; color:var(--muted); margin-bottom:6px; }
code { font-family:ui-monospace,"SF Mono",Menlo,monospace; font-size:0.85em;
  background:var(--code); padding:1px 5px; border-radius:4px; }
pre { background:var(--code); border:1px solid var(--line); border-radius:8px; padding:12px 14px;
  overflow-x:auto; font-size:0.78rem; line-height:1.5; }
pre code { background:none; padding:0; }
.tablewrap { overflow-x:auto; margin:0 0 14px; }
table { border-collapse:collapse; width:100%; font-size:0.88rem; }
th { text-align:left; font-size:0.7rem; text-transform:uppercase; letter-spacing:0.07em;
  color:var(--muted); padding:7px 10px 5px; border-bottom:1px solid var(--line); }
td { padding:8px 10px; border-bottom:1px solid var(--line); vertical-align:top; }
.st { font-family:"Avenir Next", Seravek, ui-sans-serif, system-ui, sans-serif; font-size:0.78rem;
  font-weight:600; padding:1px 8px; border-radius:99px; white-space:nowrap; }
.st-good { background:var(--good-s); color:var(--good); } .st-warn { background:var(--warn-s); color:var(--warn); }
.st-crit { background:var(--crit-s); color:var(--crit); } .st-info { background:var(--info-s); color:var(--info); }
footer { margin-top:40px; border-top:1px solid var(--line); padding-top:12px;
  font-size:0.8rem; color:var(--muted); }
.banner { background:var(--acc-soft); border:1px solid var(--line); border-radius:8px;
  padding:8px 14px; font-size:0.85rem; margin:14px 0; }
"""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("contract"); ap.add_argument("ledger"); ap.add_argument("prompt", nargs="?")
    ap.add_argument("-o", "--out", default="pack-review.html")
    args = ap.parse_args()

    files = [("contract", args.contract), ("ledger", args.ledger)]
    if args.prompt:
        files.append(("tick-prompt", args.prompt))

    sections, nav = [], []
    for anchor, path in files:
        p = pathlib.Path(path)
        try:
            body = render_md(p.read_text(encoding="utf-8"))
        except OSError as e:
            print(f"cannot read {path}: {e}", file=sys.stderr)
            return 2
        nav.append(f'<a href="#{anchor}">{anchor}</a>')
        sections.append(
            f'<section class="file" id="{anchor}"><div class="path">{html.escape(str(p))}</div>{body}</section>'
        )

    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    doc = f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>loop pack review</title><style>{CSS}</style></head><body><div class="wrap">
<nav>{''.join(nav)}<span class="tag">loop pack review</span></nav>
<h1>Loop pack review</h1>
<div class="banner">Read-only render — <strong>edit the .md files</strong>, then re-run
<code>render_pack.py</code>. The markdown is the source of truth; this page can never disagree with it.</div>
{''.join(sections)}
<footer>Rendered {stamp} by render_pack.py (deterministic — no model involved).</footer>
</div></body></html>"""
    pathlib.Path(args.out).write_text(doc, encoding="utf-8")
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
