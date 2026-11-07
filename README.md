# Translation-tool-for-D1AL-ogue

"unity_loc_tool.py" is a standalone tool, written only with the standard Python library, so it doesn't require installation. Translators don't need it.

For translators who work only with spreadsheets, the tool extracts each text table to a CSV file with three columns: source, translation, and count. Each repeated text appears only once, and the file can be opened in Excel, Google Sheets, or LibreOffice.

Workflow for another game:
1. Generate CSV files from the localization tables.
2. Verify the CSVs.
3. Generate the modified `catalog.bin` file.

4. Enable CRC checking. Without it, the game may not open. This step is only necessary for catalogs that haven't yet received this adjustment.

Limitations:

- The tool only edits the Unity Localization text tables. Texts such as "Repair Point", "Require Unit", the shortcut bar, and capture dates are not included and remain in English.

The generated bundle is not compressed, so it is larger than the original, but it remains valid.

Tables with per-entry metadata are ignored.

The tool has only been tested on Windows with Unity 6. Earlier versions are not supported.

 