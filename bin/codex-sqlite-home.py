"""Prepare a local SQLite directory before publishing it to new Codex processes."""
import os
from contextlib import closing
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tempfile


def databases(source):
    # iterdir raises if OneDrive is unavailable. An empty new home is valid.
    return sorted(p for p in source.iterdir() if p.name.endswith(".sqlite"))


def versions(files):
    result = {}
    for path in files:
        for candidate in (path, Path(str(path) + "-wal"), Path(str(path) + "-journal")):
            try:
                stat = candidate.stat()
            except FileNotFoundError:
                continue
            result[candidate] = (stat.st_ino, stat.st_size, stat.st_mtime_ns)
    return result


def check_idle(files):
    paths = [f for p in files for f in
             (p, *(Path(str(p) + s) for s in ("-wal", "-shm", "-journal"))) if f.exists()]
    if paths:
        check = subprocess.run(["/usr/sbin/lsof", "-nP", "-Fc", *paths],
                               capture_output=True, text=True)
        # macOS File Provider can retain handles after Codex quits. The version
        # check around the SQLite backups detects changes during the copy.
        owners = {line[1:] for line in check.stdout.splitlines() if line.startswith("c")}
        if check.stderr or check.returncode not in (0, 1) or owners - {"fileproviderd"}:
            raise RuntimeError("Waiting for Codex to close its existing SQLite databases")


def prepare(source, target):
    marker = ".migration-complete"
    if (target / marker).is_file():
        return
    if target.exists():
        raise RuntimeError(f"Local directory already exists without a completed migration: {target}")
    target.parent.mkdir(parents=True, exist_ok=True)
    files = databases(source)
    check_idle(files)
    before = versions(files)
    staging = Path(tempfile.mkdtemp(prefix=".codex-sqlite-", dir=target.parent))
    try:
        for path in files:
            with closing(sqlite3.connect(path.as_uri() + "?mode=ro", uri=True)) as old:
                with closing(sqlite3.connect(staging / path.name)) as new:
                    old.backup(new)
                    if new.execute("PRAGMA integrity_check").fetchall() != [("ok",)]:
                        raise RuntimeError(f"Failed integrity check for {path.name}")
        if files != databases(source) or before != versions(files):
            raise RuntimeError("Databases changed during migration")
        check_idle(files)
        (staging / marker).touch()
        staging.rename(target)
    finally:
        if staging.exists():
            shutil.rmtree(staging)


if __name__ == "__main__":
    os.umask(0o077)
    prepare(Path(sys.argv[1]).resolve(), Path(sys.argv[2]))
