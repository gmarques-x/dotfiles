#!/usr/bin/env python3
"""Set "workbench.colorTheme" in a VS Code settings.json, leaving everything else
(other settings, comments, formatting) as it is. Used by scripts/theme.
Usage: vscode-theme.py <settings.json> <theme name>"""
import json, os, re, sys

path, theme = sys.argv[1], sys.argv[2]
text = open(path).read() if os.path.exists(path) else ""
line = '"workbench.colorTheme": ' + json.dumps(theme, ensure_ascii=False)
key = re.compile(r'"workbench\.colorTheme"\s*:\s*"(?:[^"\\]|\\.)*"')

if key.search(text):
    text = key.sub(lambda _: line, text, count=1)
elif text.strip().startswith("{"):
    i = text.index("{") + 1
    if text[i:].strip().startswith("}"):
        text = "{\n    " + line + "\n}\n"
    else:
        text = text[:i] + "\n    " + line + "," + text[i:]
else:
    text = "{\n    " + line + "\n}\n"

open(path, "w").write(text)
