import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

destination = Path(sys.argv[1])
destination.mkdir(parents=True, exist_ok=True)
brew = next(Path(prefix) for prefix in ("/opt/homebrew", "/usr/local")
            if (Path(prefix) / "bin/wg-quick").is_file())
system = ("/usr/lib/", "/System/Library/")
seen = {}

def run(*arguments):
    return subprocess.check_output(arguments, text=True)

def bundle(original):
    name = original.name
    resolved = original.resolve(strict=True)
    if name in seen:
        if seen[name] != resolved:
            raise RuntimeError(f"Conflicting dependency: {name}")
        return
    seen[name] = resolved
    target = destination / name
    shutil.copyfile(resolved, target)
    target.chmod(0o755)
    if name == "wg-quick":
        return
    links = run("/usr/bin/otool", "-L", str(resolved)).splitlines()[1:]
    if name.endswith(".dylib"):
        run("/usr/bin/install_name_tool", "-id", f"@loader_path/{name}", str(target))
        links = links[1:]
    for line in links:
        dependency = re.split(r"\s+\(compatibility version", line.strip())[0]
        if dependency.startswith(system):
            continue
        candidate = Path(dependency)
        if not candidate.is_absolute() or not candidate.resolve().is_relative_to(brew.resolve()):
            raise RuntimeError(f"Unsupported dependency: {dependency}")
        bundle(candidate)
        run("/usr/bin/install_name_tool", "-change", dependency,
            f"@loader_path/{candidate.name}", str(target))
    run("/usr/bin/codesign", "--force", "--sign", "-", str(target))

for tool in ("bash", "wg", "wg-quick", "wireguard-go"):
    bundle(brew / "bin" / tool)
