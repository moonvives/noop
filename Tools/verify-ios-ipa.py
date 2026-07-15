#!/usr/bin/env python3
"""Valida uma edição arm64/iOS 26 do VWAR Loop Life antes do upload."""

from __future__ import annotations

import plistlib
import re
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT = (ROOT / "project.yml").read_text(encoding="utf-8")
FORBIDDEN_INTEGRATIONS = re.compile(
    r"\b(?:whoop|oura|garmin|fitbit|xiaomi|amazfit|huami|polar|wahoo|coros|suunto|zwift)\b",
    re.IGNORECASE,
)
FORMAT_SPECIFIER = re.compile(
    r"%(?:\d+\$)?[-+#0']*(?:\d+|\*)?(?:\.\d+|\.\*)?"
    r"(?:hh|h|ll|l|q|z|t|j)?(?:@|d|i|u|o|x|X|f|F|e|E|g|G|a|A|c|C|s|S|p|n|%)"
)

EDITIONS = {
    "iphone": {
        "profile": "iphone-16-pro-max",
        "family": {1},
        "file_suffix": "iPhone-16-Pro-Max-iOS26",
        "label": "iPhone 16 Pro Max",
        "bundle": "com.noopapp.noop.iphone",
        "widget_bundle": "com.noopapp.noop.iphone.widgets",
    },
    "ipad": {
        "profile": "ipad-pro-m2-12-9",
        "family": {2},
        "file_suffix": "iPad-Pro-M2-12.9-iPadOS26",
        "label": "iPad Pro M2 12,9",
        "bundle": "com.noopapp.noop.ipad",
        "widget_bundle": "com.noopapp.noop.ipad.widgets",
    },
}


def fail(message: str) -> None:
    print(f"ERRO IPA: {message}", file=sys.stderr)
    raise SystemExit(1)


def project_setting(name: str) -> str:
    match = re.search(rf"^\s*{re.escape(name)}:\s*[\"']?([^\"'\s]+)", PROJECT, re.MULTILINE)
    if not match:
        fail(f"configuração ausente em project.yml: {name}")
    return match.group(1)


def format_kinds(value: str) -> list[str]:
    kinds: list[str] = []
    for match in FORMAT_SPECIFIER.finditer(value):
        token = match.group(0)
        following = value[match.end():match.end() + 1]
        if len(token) == 2 and token[1].isupper() and following.isalpha():
            continue
        kinds.append(token[-1])
    return sorted(kinds)


def verify_arm64_ios26(executable: Path, label: str) -> None:
    if not executable.is_file():
        fail(f"executável ausente ({label}): {executable}")
    try:
        archs = subprocess.check_output(["lipo", "-archs", str(executable)], text=True).strip()
        build = subprocess.check_output(["xcrun", "vtool", "-show-build", str(executable)], text=True)
    except (OSError, subprocess.CalledProcessError) as error:
        fail(f"não foi possível inspecionar Mach-O de {label}: {error}")
    if archs != "arm64":
        fail(f"arquitetura de {label}: esperado somente arm64, obtido {archs!r}")
    if not re.search(r"^\s*platform\s+IOS(?:\s|$)", build, re.MULTILINE):
        fail(f"plataforma Mach-O de {label} não é iOS")
    if not re.search(r"^\s*minos\s+26\.0(?:\s|$)", build, re.MULTILINE):
        fail(f"Mach-O de {label} não exige iOS/iPadOS 26.0")


if len(sys.argv) != 3 or sys.argv[2] not in EDITIONS:
    fail("uso: verify-ios-ipa.py caminho.ipa iphone|ipad")

ipa = Path(sys.argv[1])
edition = EDITIONS[sys.argv[2]]
version = project_setting("MARKETING_VERSION")
build_number = project_setting("CURRENT_PROJECT_VERSION")
expected_filename = f"VWAR-Loop-Life-v{version}-{edition['file_suffix']}.ipa"

if not ipa.is_file() or ipa.suffix.lower() != ".ipa":
    fail(f"arquivo inválido: {ipa}")
if ipa.name != expected_filename:
    fail(f"nome incorreto: esperado {expected_filename!r}, obtido {ipa.name!r}")

with tempfile.TemporaryDirectory(prefix="vwar-ipa-") as temporary:
    root = Path(temporary)
    with zipfile.ZipFile(ipa) as archive:
        names = archive.namelist()
        if any(Path(name).is_absolute() or ".." in Path(name).parts for name in names):
            fail("o ZIP contém caminhos inseguros")
        design_ptbr = [
            name for name in names
            if "StrandDesign_StrandDesign.bundle/pt-BR.lproj/Localizable.strings" in name
        ]
        if len(design_ptbr) < 2:
            fail("recursos pt-BR do sistema visual ausentes no aplicativo ou widget")
        if any(name.endswith("embedded.mobileprovision") for name in names):
            fail("o pacote ready-to-sign contém perfil de provisionamento de terceiros")
        archive.extractall(root)

    apps = list((root / "Payload").glob("*.app"))
    if len(apps) != 1:
        fail(f"esperado um aplicativo no Payload; encontrados {len(apps)}")
    app = apps[0]
    if (app / "Watch").exists() or list(app.rglob("*.app")):
        fail("o IPA contém aplicativo aninhado ou Apple Watch fora do escopo")

    with (app / "Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    expected = {
        "CFBundleDisplayName": "VWAR Loop Life",
        "CFBundleShortVersionString": version,
        "CFBundleVersion": build_number,
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
    if {int(value) for value in info.get("UIDeviceFamily", [])} != edition["family"]:
        fail(f"UIDeviceFamily divergente para {edition['label']}")
    if "arm64" not in set(info.get("UIRequiredDeviceCapabilities", [])):
        fail("UIRequiredDeviceCapabilities não exige arm64")
    if "NSBluetoothAlwaysUsageDescription" in info:
        fail("a edição Saúde/Strava não deve declarar acesso Bluetooth")
    if "bluetooth-central" in info.get("UIBackgroundModes", []):
        fail("a edição Saúde/Strava não deve executar Bluetooth em segundo plano")
    if "location" in info.get("UIBackgroundModes", []):
        fail("a edição Saúde/Strava não deve manter localização em segundo plano")
    if "NSLocationWhenInUseUsageDescription" in info:
        fail("a edição Saúde/Strava não deve solicitar localização")
    if "NSAppTransportSecurity" in info:
        fail("a edição HealthKit-only não deve abrir exceção de rede local")
    for key in (
        "NSHealthShareUsageDescription",
        "NSHealthUpdateUsageDescription",
    ):
        if not str(info.get(key, "")).startswith("O VWAR Loop Life"):
            fail(f"permissão fora de pt-BR: {key}")

    app_executable = info.get("CFBundleExecutable")
    if not isinstance(app_executable, str):
        fail("CFBundleExecutable do aplicativo ausente")
    verify_arm64_ios26(app / app_executable, "aplicativo")

    catalog_path = app / "pt-BR.lproj" / "Localizable.strings"
    if not catalog_path.is_file():
        fail("catálogo principal pt-BR ausente")
    with catalog_path.open("rb") as handle:
        catalog = plistlib.load(handle)
    if len(catalog) != 2_988:
        fail(f"catálogo principal incompleto: {len(catalog)} de 2988 entradas")
    required = {
        "Low battery": "Bateria fraca",
        "Recharge your WHOOP before tonight.": "Recarregue sua VWAR Loop Life antes desta noite.",
        "Your WHOOP is at 100%.": "Sua VWAR Loop Life está com 100% de bateria.",
        "Smart alarm": "Alarme inteligente",
    }
    for key, value in required.items():
        if catalog.get(key) != value:
            fail(f"tradução divergente para {key!r}")
    for key, value in catalog.items():
        if FORBIDDEN_INTEGRATIONS.search(str(value)):
            fail(f"catálogo expõe integração fora do escopo: {value!r}")
        if format_kinds(str(key)) != format_kinds(str(value)):
            fail(f"especificadores de formato divergentes para {key!r}")

    widgets = list((app / "PlugIns").glob("*.appex"))
    if len(widgets) != 1:
        fail(f"esperado um widget/Atividade ao Vivo; encontrados {len(widgets)}")
    widget = widgets[0]
    with (widget / "Info.plist").open("rb") as handle:
        widget_info = plistlib.load(handle)
    widget_expected = {
        "CFBundleDisplayName": "VWAR Loop Life",
        "CFBundleShortVersionString": version,
        "CFBundleVersion": build_number,
        "MinimumOSVersion": "26.0",
        "CFBundleDevelopmentRegion": "pt-BR",
        "CFBundleIdentifier": edition["widget_bundle"],
    }
    for key, value in widget_expected.items():
        if str(widget_info.get(key)) != value:
            fail(f"widget {key}: esperado {value!r}, obtido {widget_info.get(key)!r}")
    if widget_info.get("CFBundleLocalizations") != ["pt-BR"]:
        fail("localização do widget não é exclusivamente pt-BR")
    if {int(value) for value in widget_info.get("UIDeviceFamily", [])} != edition["family"]:
        fail("família do widget diverge do aplicativo")
    widget_executable = widget_info.get("CFBundleExecutable")
    if not isinstance(widget_executable, str):
        fail("CFBundleExecutable do widget ausente")
    verify_arm64_ios26(widget / widget_executable, "widget")

    app_intents = app / "Metadata.appintents"
    if app_intents.exists():
        metadata = "\n".join(
            path.read_text(encoding="utf-8", errors="ignore")
            for path in app_intents.rglob("*") if path.is_file()
        )
        if FORBIDDEN_INTEGRATIONS.search(metadata):
            fail("metadados de Atalhos expõem integração fora do escopo")

print(
    f"IPA verificado: {ipa.name} ({ipa.stat().st_size} bytes), "
    f"{edition['label']}, somente arm64, sistema 26 e pt-BR."
)
