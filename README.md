#unity-loc-tool

Tool (Python 3.8+, no dependencies) to translate **Unity games that use Unity Localization + Addressables**.

Tested with D1AL-ogue (Unity 6000.0.61f1). Works with LZ4, LZMA bundles or without compression.

## 4-Step Flow

```
python unity_loc_tool.py extract "<bundle of en-US texts>" -o projects/MyGame/pt-BR

(translate the CSVs)
python unity_loc_tool.py check projects/MyGame/pt-BR [--font font.ttf]
python unity_loc_tool.py build "<bundle>" projects/MyGame/pt-BR -o output --catalog ".../aa/catalog.bin"
python unity_loc_tool.py install output --game "C:\...\MyGame" # makes a backup (.bak)
python unity_loc_tool.py restore --game "C:\...\MyGame" # undoes
```

- `extract` can be run again after a game update: it keeps what has already been translated, adds new texts, and informs about the removed ones.

- `check` verifies if `<tags>`, `{0}`, `\n` and line breaks match the original and if the **game font** has the characters used (`--font`, requires `pip install fonttools`). Returns an error if there is a problem (good for CI).

- `build` ignores (and warns about) translations with formatting problems, so as not to break the game.

- `--catalog` resets the bundle's CRC in `catalog.bin` (Addressables rejects modified bundles). Without this, the game may not open or may show broken menus.

## For translators
See [CONTRIBUTING.md](CONTRIBUTING.md). No installation required: edit the CSVs and open a Pull Request.

## Known limitations
- Only edits **StringTables** of Unity Localization. Fixed text in the interface (e.g., "Repair Point," shortcut bar, dates) is located in other assets and is not yet covered.

The generated bundle is uncompressed (larger, but valid).

Tables with per-entry metadata are skipped. JSON catalogs (old Addressables) do not yet have automatic CRC adjustment.

Tested only on Windows/Unity 6; older versions of SerializedFile (< v17) are not supported.

We do not distribute game files. Use copies that you own.

 