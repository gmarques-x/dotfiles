#!/usr/bin/env python3
"""Save the desktop palette through the Codex app server."""

import json
import subprocess
import sys
from threading import Timer


def exchange(server, method, params=None, request_id=None):
    message = {"method": method}
    if params is not None:
        message["params"] = params
    if request_id is not None:
        message["id"] = request_id
    server.stdin.write(json.dumps(message) + "\n")
    server.stdin.flush()
    if request_id is None:
        return
    for line in server.stdout:
        reply = json.loads(line)
        if reply.get("id") == request_id:
            if "error" in reply:
                raise RuntimeError(reply["error"]["message"])
            return reply["result"]
    raise RuntimeError("The Codex app server closed before replying")


def main():
    codex, mode, bg, fg, accent, green, red, purple = sys.argv[1:]
    variant = {"dark": "Dark", "light": "Light"}[mode]
    palette = {
        "accent": accent,
        "accentSource": "custom",
        "contrast": 60 if mode == "dark" else 45,
        "fonts": {},
        "ink": fg,
        "opaqueWindows": True,
        "semanticColors": {"diffAdded": green, "diffRemoved": red, "skill": purple},
        "surface": bg,
    }
    edits = [
        {"keyPath": "desktop.appearanceTheme", "value": mode, "mergeStrategy": "replace"},
        {
            "keyPath": f"desktop.appearance{variant}ChromeTheme",
            "value": palette,
            "mergeStrategy": "upsert",
        },
    ]
    with subprocess.Popen(
        [codex, "app-server"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    ) as server:
        timeout = Timer(10, server.kill)
        timeout.start()
        try:
            exchange(server, "initialize", {"clientInfo": {"name": "dotfiles-theme", "version": "1"}}, 1)
            exchange(server, "initialized")
            exchange(server, "config/batchWrite", {"edits": edits}, 2)
        finally:
            timeout.cancel()
            server.terminate()


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError) as error:
        sys.exit(f"Codex desktop theme: {error}")
