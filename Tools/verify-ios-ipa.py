#!/usr/bin/env python3
"""Valida o IPA universal iPhone/iPad produzido pelo CI antes do upload."""

from __future__ import annotations

import plistlib
import sys
import tempfile
import zipfile
from pathlib import Path


def fail(message: str) -> None:
    print(f"ERRO IPA: {message}", file=sys.stderr)
    raise SystemExit(1)


if len(sys.argv) != 2:
    fail("uso: verify-ios-ipa.py caminho.ipa")

ipa = Path(sys.argv[1])
if not ipa.is_file() or ipa.suffix.lower() != ".ipa":
    fail(f"arquivo inválido: {ipa}")

with tempfile.TemporaryDirectory(prefix="vwar-ipa-") as temporary:
    root = Path(temporary)
    with zipfile.ZipFile(ipa) as archive:
        bad = [name for name in archive.namelist() if Path(name).is_absolute() or ".." in Path(name).parts]
        if bad:
            fail("o ZIP contém caminhos inseguros")
        archive.extractall(root)

    apps = list((root / "Payload").glob("*.app"))
    if len(apps) != 1:
        fail(f"esperado um aplicativo no Payload; encontrados {len(apps)}")
    app = apps[0]
    with (app / "Info.plist").open("rb") as handle:
        info = plistlib.load(handle)

    expected = {
        "CFBundleDisplayName": "VWAR Loop Life",
        "CFBundleShortVersionString": "10.0.0",
        "CFBundleVersion": "173",
        "MinimumOSVersion": "26.0",
        "CFBundleDevelopmentRegion": "pt-BR",
    }
    for key, value in expected.items():
        if str(info.get(key)) != value:
            fail(f"{key}: esperado {value!r}, obtido {info.get(key)!r}")

    if info.get("CFBundleLocalizations") != ["pt-BR"]:
        fail("CFBundleLocalizations não contém exclusivamente pt-BR")
    family = {int(value) for value in info.get("UIDeviceFamily", [])}
    if family != {1, 2}:
        fail(f"UIDeviceFamily deve ser iPhone+iPad [1,2], obtido {sorted(family)}")

    for key in (
        "NSBluetoothAlwaysUsageDescription",
        "NSHealthShareUsageDescription",
        "NSHealthUpdateUsageDescription",
        "NSLocationWhenInUseUsageDescription",
    ):
        if not str(info.get(key, "")).startswith("O VWAR Loop Life"):
            fail(f"permissão fora de pt-BR: {key}")

    widgets = list((app / "PlugIns").glob("*.appex"))
    if not widgets:
        fail("extensão de widget/Atividade ao Vivo ausente")

print(f"IPA verificado: {ipa.name} ({ipa.stat().st_size} bytes), iPhone+iPad, iOS 26, pt-BR.")
