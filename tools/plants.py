"""Planted source defects: apply each alone, run the checks, and say whether they noticed.

    python tools/plants.py tests/plants/<name>.py            run every plant of a roster
    python tools/plants.py tests/plants/<name>.py check      only verify that every site occurs once
    python tools/plants.py tests/plants/<name>.py 3 7        run the plants with those indices

A roster is a Python file defining

    PASS_MARKS = ("A-LINE-THE-CHECK-PRINTS-ON-SUCCESS", ...)
    PLANTS = [(file, label, old, new), ...]          # or (file, label, old, new, expected)

Each plant replaces OLD, which must occur exactly once in FILE, by NEW. The verdicts:

    CAUGHT    the planted source compiled and a pass mark is missing: the tests noticed
    MISSED    the planted source compiled and every pass mark is present
    INVALID   the planted source did not compile, so nothing was tested

A plant that does not compile proves nothing, and a runner that counted it as caught would
flatter the tests; that is why INVALID is its own verdict. EXPECTED, by default CAUGHT, is
there so that a roster can hold the runner's own controls. The run fails unless every plant
has its expected verdict and the restored sources pass.

One process at a time. Sources are restored whatever happens. Logs go under build/plants/.
"""

from __future__ import annotations

import pathlib
import runpy
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
LOGS = ROOT / "build" / "plants"
COMMAND = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "scripts" / "check.ps1"),
           "-Safety", "1", "-DynamicSpaceMb", "1024"]
NOT_COMPILED = ("COMPILE-FILE-ERROR", "The compiler warned while building", "Invalid toplevel form",
                "READ error", "end of file on")


def run(log_name: str, pass_marks) -> tuple[list[str], bool]:
    """Run the checks. Returns the pass marks seen and whether the sources failed to compile."""
    done = subprocess.run(COMMAND, capture_output=True, text=True, cwd=ROOT)
    text = done.stdout + "\n" + done.stderr
    LOGS.mkdir(parents=True, exist_ok=True)
    (LOGS / log_name).write_text(text, encoding="utf-8", errors="replace")
    return [mark for mark in pass_marks if mark in text], any(sign in text for sign in NOT_COMPILED)


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    roster_path = pathlib.Path(sys.argv[1]).resolve()
    roster = runpy.run_path(str(roster_path))
    pass_marks = tuple(roster["PASS_MARKS"])
    plants = [tuple(plant) + ("CAUGHT",) * (5 - len(plant)) for plant in roster["PLANTS"]]
    originals = {}
    for name, label, old, new, expected in plants:
        if name not in originals:
            originals[name] = (ROOT / name).read_bytes().decode("utf-8")
        count = originals[name].count(old)
        if count != 1:
            print(f"The site of '{label}' occurs {count} times in {name}, not once.")
            return 2
        if old == new:
            print(f"'{label}' changes nothing.")
            return 2
    selected = sys.argv[2:]
    if selected == ["check"]:
        print(f"{len(plants)} plants, every site occurs once")
        return 0
    stem = roster_path.stem
    as_expected = True
    try:
        for index, (name, label, old, new, expected) in enumerate(plants):
            if selected and str(index) not in selected:
                continue
            (ROOT / name).write_bytes(originals[name].replace(old, new).encode("utf-8"))
            try:
                seen, not_compiled = run(f"{stem}-{index}.log", pass_marks)
            finally:
                (ROOT / name).write_bytes(originals[name].encode("utf-8"))
            verdict = "INVALID" if not_compiled else ("CAUGHT" if len(seen) < len(pass_marks) else "MISSED")
            as_expected = as_expected and verdict == expected
            note = "" if verdict == expected else f"   <-- expected {expected}"
            print(f"{index} {verdict}: {label}{note}", flush=True)
    finally:
        for name, original in originals.items():
            (ROOT / name).write_bytes(original.encode("utf-8"))
    seen, not_compiled = run(f"{stem}-restored.log", pass_marks)
    restored = len(seen) == len(pass_marks) and not not_compiled
    print("restored: " + ("all pass" if restored else f"NOT passing; marks seen: {seen}"), flush=True)
    return 0 if as_expected and restored else 1


if __name__ == "__main__":
    sys.exit(main())
