#!/usr/bin/env python3
"""Valida um IPA dedicado do VWAR Loop Life 11 antes do upload."""

from __future__ import annotations

import plistlib
import sys
import tempfile
import zipfile
from pathlib import Path


EDITIONS = {
    "iphone": {
        "profile": "iphone-16-pro-max",
        "family": {1},
        "file_fragment": "iPhone-16-Pro-Max",
        "label": "iPhone 16 Pro Max",
        "bundle": "com.noopapp.noop.iphone",
        "widget_bundle": "com.noopapp.noop.iphone.widgets",
    },
    "ipad": {
        "profile": "ipad-pro-m2-12-9",
        "family": {2},
        "file_fragment": "iPad-Pro-M2-12.9",
        "label": "iPad Pro M2 12,9",
        "bundle": "com.noopapp.noop.ipad",
        "widget_bundle": "com.noopapp.noop.ipad.widgets",
    },
}


def fail(message: str) -> None:
    print(f"ERRO IPA: {message}", file=sys.stderr)
    raise SystemExit(1)


if len(sys.argv) != 3 or sys.argv[2] not in EDITIONS:
    fail("uso: verify-ios-ipa.py caminho.ipa iphone|ipad")

ipa = Path(sys.argv[1])
edition = EDITIONS[sys.argv[2]]
if not ipa.is_file() or ipa.suffix.lower() != ".ipa":
    fail(f"arquivo inválido: {ipa}")
if edition["file_fragment"] not in ipa.name:
    fail(f"o nome do arquivo não identifica {edition['label']}: {ipa.name}")

with tempfile.TemporaryDirectory(prefix="vwar-ipa-") as temporary:
    root = Path(temporary)
    with zipfile.ZipFile(ipa) as archive:
        names = archive.namelist()
        bad = [name for name in names if Path(name).is_absolute() or ".." in Path(name).parts]
        if bad:
            fail("o ZIP contém caminhos inseguros")
        ptbr_design_resources = [
            name for name in names
            if "StrandDesign_StrandDesign.bundle/pt-BR.lproj/Localizable.strings" in name
        ]
        if len(ptbr_design_resources) < 2:
            fail("recursos pt-BR do sistema visual ausentes no aplicativo ou no widget")
        if any(name.endswith("embedded.mobileprovision") for name in names):
            fail("o pacote não pode conter perfil de provisionamento de terceiros")
        archive.extractall(root)

    apps = list((root / "Payload").glob("*.app"))
    if len(apps) != 1:
        fail(f"esperado um aplicativo no Payload; encontrados {len(apps)}")
    app = apps[0]
    with (app / "Info.plist").open("rb") as handle:
        info = plistlib.load(handle)

    expected = {
        "CFBundleDisplayName": "VWAR Loop Life",
        "CFBundleShortVersionString": "11.0.0",
        "CFBundleVersion": "174",
        "MinimumOSVersion": "26.0",
        "CFBundleDevelopmentRegion": "pt-BR",
        "VWARDeviceEdition": edition["profile"],
        "CFBundleIdentifier": edition["bundle"],
    }
    for key, value in expected.items():
        if str(info.get(key)) != value:
            fail(f"{key}: esperado {value!r}, obtido {info.get(key)!r}")

    if info.get("CFBundleLocalizations") != ["pt-BR"]:
        fail("CFBundleLocalizations não contém exclusivamente pt-BR")
    family = {int(value) for value in info.get("UIDeviceFamily", [])}
    if family != edition["family"]:
        fail(f"UIDeviceFamily de {edition['label']} inválida: {sorted(family)}")
    capabilities = set(info.get("UIRequiredDeviceCapabilities", []))
    if "arm64" not in capabilities:
        fail("UIRequiredDeviceCapabilities não exige arm64")

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
    for widget in widgets:
        with (widget / "Info.plist").open("rb") as handle:
            widget_info = plistlib.load(handle)
        widget_family = {int(value) for value in widget_info.get("UIDeviceFamily", [])}
        if widget_family != edition["family"]:
            fail(f"widget com família divergente: {sorted(widget_family)}")
        if str(widget_info.get("MinimumOSVersion")) != "26.0":
            fail("widget não exige iOS/iPadOS 26")
        if str(widget_info.get("CFBundleIdentifier")) != edition["widget_bundle"]:
            fail(f"identificador do widget divergente: {widget_info.get('CFBundleIdentifier')!r}")

print(
    f"IPA verificado: {ipa.name} ({ipa.stat().st_size} bytes), "
    f"{edition['label']}, arm64, sistema 26, pt-BR."
)
