# How to help translate

1. Open the CSV table file in `projects/<game>/<language>/` (Excel, LibreOffice, or Google Sheets; UTF-8 encoding).

`DialogueTable_*.csv` is the largest (dialogues).

2. Fill in **only** the `translation` column. Empty line = continues in English in the game.

3. Rules:

- Keep identical: `<color=...>`, `<blink>`, `<shake ...>`, `{0}`, `{1}` and `\n` (slash + n). Do not replace with a real line break.

- Do not use curly quotes or characters outside the game's font (run `check --font`).

- Short dialogues: the game's speech bubble is small. Avoid texts much longer than the English version.

- Consistency: Chroma City, Neon Shine, E.V.E., Chromatic Zenith, Polar Daynight (see glossary below).
4. Run `python unity_loc_tool.py check projects/<game>/<language>` before submitting. CI does the same check.
5. Open a Pull Request. A table or a snippet of lines per PR facilitates review.

## Glossary (D1AL-ogue pt-BR)
Chroma City · Neon Shine · E.V.E.(s) · Stability Officers · Chromatic Zenith · Polar Daynight ·
LDS (Light Deficiency Syndrome) · Energy/Logic/Neural Unit · Synaptic Unit · Manager (Chris).
 