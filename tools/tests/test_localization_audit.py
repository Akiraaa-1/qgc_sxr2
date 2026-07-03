#!/usr/bin/env python3
"""Tests for tools/translations/localization_audit.py."""

from __future__ import annotations

from pathlib import Path

from translations.localization_audit import audit_file, is_generated_path


def test_detects_bom(tmp_path: Path) -> None:
    repo_root = tmp_path
    path = repo_root / "src" / "Sample.qml"
    path.parent.mkdir(parents=True)
    path.write_bytes(b"\xef\xbb\xbfimport QtQuick\n")

    issues = audit_file(repo_root, path)

    assert any("UTF-8 BOM" in issue for issue in issues)


def test_detects_suspicious_encoding_artifact(tmp_path: Path) -> None:
    repo_root = tmp_path
    path = repo_root / "translations" / "LOCALIZATION_RULES.md"
    path.parent.mkdir(parents=True)
    path.write_text("Actuators -> 鎵ц鍣�\n", encoding="utf-8")

    issues = audit_file(repo_root, path)

    assert any("suspicious encoding artifact" in issue for issue in issues)


def test_detects_blocked_term(tmp_path: Path) -> None:
    repo_root = tmp_path
    path = repo_root / "src" / "UI" / "MainWindow.qml"
    path.parent.mkdir(parents=True)
    path.write_text('text: qsTr("Start Mission")\n', encoding="utf-8")

    issues = audit_file(repo_root, path)

    assert any("blocked English source term `Start Mission`" in issue for issue in issues)


def test_generated_path_detection(tmp_path: Path) -> None:
    repo_root = tmp_path
    path = repo_root / "build" / "debug" / "foo.qml"
    path.parent.mkdir(parents=True)
    path.write_text("import QtQuick\n", encoding="utf-8")

    assert is_generated_path(repo_root, path)
    issues = audit_file(repo_root, path)
    assert any("generated/build path" in issue for issue in issues)
