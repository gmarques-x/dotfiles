#!/usr/bin/env python3
"""Apply a static image to all Spaces in the macOS WallpaperAgent store."""
import os
import plistlib
import pwd
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path


def set_desktop(entry, desktop):
    # A linked wallpaper serves as both desktop and screen saver. Keep its
    # screen saver when assigning a separate static desktop image.
    if "Linked" in entry:
        entry["Idle"] = entry.pop("Linked")
    entry["Desktop"] = desktop
    entry["Type"] = "individual" if "Idle" in entry else "desktop"


def apply(image):
    if not image.is_file():
        raise ValueError(f"Wallpaper image missing: {image}")
    store = Path.home() / "Library/Application Support/com.apple.wallpaper/Store/Index.plist"
    index = plistlib.loads(store.read_bytes())
    if not {"AllSpacesAndDisplays", "Spaces", "Displays"} <= index.keys():
        raise ValueError("Unrecognized macOS wallpaper store")
    config = {"type": "imageFile", "url": {"relative": image.resolve().as_uri()}}
    choice = {"Provider": "com.apple.wallpaper.choice.image", "Files": [],
              "Configuration": plistlib.dumps(config, fmt=plistlib.FMT_BINARY)}
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    # WallpaperAgent stores the Fill Screen placement under the ID "Crop".
    options = {"values": {"placement": {"picker": {"_0": {"id": "Crop"}}}}}
    desktop = {"Content": {"Choices": [choice], "Shuffle": "$null",
                           "EncodedOptionValues": plistlib.dumps(options, fmt=plistlib.FMT_BINARY)},
               "LastSet": now, "LastUse": now}

    if index["AllSpacesAndDisplays"] == "$null":
        index["AllSpacesAndDisplays"] = {}
    set_desktop(index["AllSpacesAndDisplays"], desktop)
    entries = [index.get("SystemDefault"), *index["Displays"].values()]
    for space in index["Spaces"].values():
        entries.append(space.get("Default"))
        entries.extend(space.get("Displays", {}).values())
    for entry in entries:
        if isinstance(entry, dict) and ("Desktop" in entry or "Linked" in entry):
            set_desktop(entry, desktop)

    # Replace atomically so WallpaperAgent always sees a complete plist.
    with tempfile.NamedTemporaryFile(dir=store.parent, delete=False) as tmp:
        try:
            plistlib.dump(index, tmp, fmt=plistlib.FMT_BINARY, sort_keys=False)
            tmp.flush()
            os.replace(tmp.name, store)
        finally:
            Path(tmp.name).unlink(missing_ok=True)
    subprocess.run(["killall", "-u", pwd.getpwuid(os.getuid()).pw_name, "WallpaperAgent"], check=True)


if __name__ == "__main__":
    try:
        apply(Path(sys.argv[1]))
    except (OSError, ValueError, plistlib.InvalidFileException, subprocess.CalledProcessError) as error:
        sys.exit(f"Could not apply wallpaper to all Spaces: {error}")
