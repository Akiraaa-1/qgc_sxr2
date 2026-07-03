#!/usr/bin/env python3
"""Local audit checks for QGC localization sources."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from common.file_traversal import find_repo_root, should_skip_path

TEXT_EXTENSIONS = frozenset({".qml", ".js", ".json", ".ts", ".xml", ".qrc", ".md"})
DEFAULT_ROOTS = ("src", "translations", "tools", "AGENTS.md", ".gitattributes")
UTF8_BOM = b"\xef\xbb\xbf"
SUSPICIOUS_SNIPPETS = (
    "锟",
    "鈥",
    "鎽",
    "璁剧疆",
    "寮€",
    "涓",
    "鐢垫満",
    "\ufffd",
)
BLOCKED_TERMS = {
    "src/UI/MainWindow.qml": (
        "Start Mission",
        "Slide or hold spacebar",
        "Vehicle Error",
        "Additional errors received",
    ),
    "src/AutoPilotPlugins/PX4/ActuatorComponent.qml": (
        "Identify & Assign Motors",
        "Motor Order Identification and Assignment",
        "Spin Motor Again",
        "Abort",
    ),
    "src/AutoPilotPlugins/PX4/ESCCalibrationDialog.qml": (
        "ESC Calibration",
        "Calibrate",
    ),
    "src/Vehicle/VehicleSetup/JoystickComponent.qml": (
        "Enable Joystick",
        "Not currently available",
        "Requires Calibration",
    ),
    "src/Vehicle/VehicleSetup/VehicleConfigMenu.qml": (
        "Actuators",
    ),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Audit localization sources for encoding and regression issues.")
    parser.add_argument("paths", nargs="*", help="Files or directories to scan")
    return parser.parse_args()


def iter_text_files(repo_root: Path, raw_paths: list[str]) -> list[Path]:
    scan_paths = raw_paths or list(DEFAULT_ROOTS)
    files: list[Path] = []

    for raw_path in scan_paths:
        path = (repo_root / raw_path).resolve()
        if not path.exists():
            continue
        if path.is_file():
            if path.suffix in TEXT_EXTENSIONS or path.name in {"AGENTS.md", ".gitattributes"}:
                files.append(path)
            continue
        for child in path.rglob("*"):
            if child.is_file() and child.suffix in TEXT_EXTENSIONS:
                rel = child.relative_to(repo_root)
                if not should_skip_path(rel):
                    files.append(child)

    return sorted({file.resolve() for file in files})


def is_generated_path(repo_root: Path, path: Path) -> bool:
    rel_str = path.relative_to(repo_root).as_posix()
    return (
        rel_str.startswith("build/")
        or "/build/" in rel_str
        or rel_str.startswith(".rcc/")
        or "/.rcc/" in rel_str
    )


def audit_file(repo_root: Path, path: Path) -> list[str]:
    issues: list[str] = []
    rel_str = path.relative_to(repo_root).as_posix()
    raw = path.read_bytes()

    if raw.startswith(UTF8_BOM):
        issues.append(f"{rel_str}: contains UTF-8 BOM")

    if is_generated_path(repo_root, path):
        issues.append(f"{rel_str}: generated/build path should not be edited")

    text = raw.decode("utf-8", errors="replace")

    for snippet in SUSPICIOUS_SNIPPETS:
        if snippet in text:
            issues.append(f"{rel_str}: contains suspicious encoding artifact `{snippet}`")
            break

    for blocked_term in BLOCKED_TERMS.get(rel_str, ()):
        if blocked_term in text:
            issues.append(f"{rel_str}: still contains blocked English source term `{blocked_term}`")

    return issues


def main() -> int:
    args = parse_args()
    repo_root = find_repo_root(Path(__file__))
    files = iter_text_files(repo_root, args.paths)

    issues: list[str] = []
    for file in files:
        issues.extend(audit_file(repo_root, file))

    if issues:
        for issue in issues:
            print(issue)
        return 1

    print(f"Localization audit passed ({len(files)} files checked)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
