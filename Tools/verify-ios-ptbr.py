#!/usr/bin/env python3
"""Audita a experiência iOS 26 em pt-BR sem enviar código ou catálogo à rede."""

from __future__ import annotations

import json
import plistlib
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN_INTEGRATIONS = re.compile(
    r"\b(?:whoop|oura|garmin|fitbit|xiaomi|amazfit|huami|polar|wahoo|coros|suunto|zwift)\b",
    re.IGNORECASE,
)
FORMAT_SPECIFIER = re.compile(
    r"%(?:\d+\$)?[-+#0']*(?:\d+|\*)?(?:\.\d+|\.\*)?"
    r"(?:hh|h|ll|l|q|z|t|j)?(?:@|d|i|u|o|x|X|f|F|e|E|g|G|a|A|c|C|s|S|p|n|%)"
)

ACTIVE_SURFACES = [
    ROOT / "Strand/App/Terms.swift",
    ROOT / "Strand/System/AppChangelog.swift",
    ROOT / "Strand/System/BatteryNotifier.swift",
    ROOT / "Strand/System/IllnessNotifier.swift",
    ROOT / "Strand/System/WindDownNudge.swift",
    ROOT / "StrandiOS/App/StrandiOSApp.swift",
    ROOT / "StrandiOS/App/RootTabView.swift",
    ROOT / "StrandiOS/App/SiriShortcutsSettingsView.swift",
    ROOT / "StrandiOS/App/VWARDeviceEdition.swift",
    ROOT / "StrandiOS/Health/HealthKitBridge.swift",
    ROOT / "StrandiOS/System/NOOPAppIntents.swift",
    ROOT / "StrandiOS/VITAE/VITAEPerformanceDashboard.swift",
    ROOT / "StrandiOS/VITAE/VWARNavigationChrome.swift",
    ROOT / "StrandiOS/VITAE/VWARLoopLife26Experience.swift",
    ROOT / "StrandiOS/VITAE/VWARPortugueseGates.swift",
    ROOT / "StrandiOSWidgets/NOOPWidget.swift",
    ROOT / "StrandiOSWidgets/NOOPLiveActivity.swift",
    ROOT / "StrandiOSShared/LiveActivityAttributes.swift",
]

BANNED_UI_LITERALS = {
    "Today", "Trends", "Sleep", "More", "Done", "Open", "Support", "Profile",
    "About you", "Bring your history", "Save & Continue", "Continue", "Recovery",
    "Effort", "Rest", "Charge", "Battery", "Live HR",
}
ALLOWED_INTERNAL_LITERALS = {"my-whoop"}


def fail(message: str) -> None:
    print(f"ERRO pt-BR: {message}", file=sys.stderr)
    raise SystemExit(1)


def swift_literals(text: str) -> set[str]:
    without_comments = re.sub(r"//.*?$|/\*.*?\*/", "", text, flags=re.MULTILINE | re.DOTALL)
    return set(re.findall(r'"((?:\\.|[^"\\])*)"', without_comments))


def format_kinds(value: str) -> list[str]:
    kinds: list[str] = []
    for match in FORMAT_SPECIFIER.finditer(value):
        token = match.group(0)
        following = value[match.end():match.end() + 1]
        if len(token) == 2 and token[1].isupper() and following.isalpha():
            continue
        kinds.append(token[-1])
    return sorted(kinds)


for path in ACTIVE_SURFACES:
    if not path.is_file():
        fail(f"superfície obrigatória ausente: {path.relative_to(ROOT)}")
    literals = swift_literals(path.read_text(encoding="utf-8"))
    leaked = sorted(BANNED_UI_LITERALS.intersection(literals))
    if leaked:
        fail(f"{path.relative_to(ROOT)} contém rótulos em inglês: {', '.join(leaked)}")

project = (ROOT / "project.yml").read_text(encoding="utf-8")
for fragment in (
    'NOOPiOS:',
    'deploymentTarget: "26.0"',
    'MARKETING_VERSION: "11.1.0"',
    'CURRENT_PROJECT_VERSION: "175"',
    'CFBundleDevelopmentRegion: pt-BR',
    '- pt-BR',
    'VWAR_DEVICE_EDITION: adaptive',
    'VWARDeviceEdition: "$(VWAR_DEVICE_EDITION)"',
    'VWAR_APP_BUNDLE_ID: com.noopapp.noop',
    'VWAR_WIDGET_BUNDLE_ID: com.noopapp.noop.widgets',
    '- "Onboarding"',
    '- "Liquid/LiquidTodayView.swift"',
    '- "Screens/DataSourcesView.swift"',
    '- "Screens/CoachView.swift"',
    '- "Screens/DevicesView.swift"',
    '- "Screens/AddDeviceWizard.swift"',
    '- "Data/WatchSessionBridge.swift"',
):
    if fragment not in project:
        fail(f"project.yml não contém {fragment!r}")

with (ROOT / "StrandiOS/Resources/Info.plist").open("rb") as handle:
    info = plistlib.load(handle)
if info.get("CFBundleDevelopmentRegion") != "pt-BR":
    fail("CFBundleDevelopmentRegion do aplicativo não é pt-BR")
if info.get("CFBundleLocalizations") != ["pt-BR"]:
    fail("CFBundleLocalizations do aplicativo deve conter apenas pt-BR")
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
        fail(f"{key} não está em português do Brasil")

catalog_path = ROOT / "StrandiOS/Resources/pt-BR.lproj/Localizable.strings"
if not catalog_path.is_file():
    fail("catálogo principal pt-BR ausente")
with catalog_path.open("rb") as handle:
    catalog = plistlib.load(handle)
if len(catalog) != 2_988:
    fail(f"catálogo principal incompleto: {len(catalog)} de 2988 entradas")
required_translations = {
    "Low battery": "Bateria fraca",
    "Recharge your WHOOP before tonight.": "Recarregue sua VWAR Loop Life antes desta noite.",
    "Your WHOOP is at 100%.": "Sua VWAR Loop Life está com 100% de bateria.",
    "Time to wind down": "Hora de relaxar",
    "Smart alarm": "Alarme inteligente",
}
for key, value in required_translations.items():
    if catalog.get(key) != value:
        fail(f"tradução principal divergente para {key!r}")
for key, value in catalog.items():
    if FORBIDDEN_INTEGRATIONS.search(str(value)):
        fail(f"catálogo pt-BR expõe integração fora do escopo: {value!r}")
    if format_kinds(str(key)) != format_kinds(str(value)):
        fail(f"especificadores de formato divergentes para {key!r}")

active_text = "\n".join(path.read_text(encoding="utf-8") for path in ACTIVE_SURFACES)
for required in (
    "VWARPortugueseOnboarding",
    "VWARPortugueseTermsGate",
    "VWARTrendsView",
    "VWARSleepIntelligenceView",
    "VWARSourcesView",
    "VWARPhoneDock",
    "VWARiPadRail",
    "iphone-16-pro-max",
    "ipad-pro-m2-12-9",
    "G Band",
    "Strava",
):
    if required not in active_text:
        fail(f"experiência obrigatória ausente: {required}")
if "VITAE One" in active_text or "VITAE One" in project:
    fail("o nome legado VITAE One ainda aparece na edição iOS")
for legacy_type in (
    "OnboardingWizard", "TodayView()", "TrendsView()", "SleepView()",
    "AppleHealthView()", "SettingsView()", "DevicesView()", "AddDeviceWizard",
):
    if re.search(rf"(?<![A-Za-z0-9_]){re.escape(legacy_type)}", active_text):
        fail(f"a edição iOS ainda alcança tela legada: {legacy_type}")
for literal in swift_literals(active_text):
    if literal not in ALLOWED_INTERNAL_LITERALS and FORBIDDEN_INTEGRATIONS.search(literal):
        fail(f"interface ativa expõe integração fora do escopo: {literal!r}")
    if re.search(r"\b(?:Bluetooth|BLE)\b", literal, re.IGNORECASE):
        fail(f"interface ativa ainda expõe conexão direta: {literal!r}")

runtime = (ROOT / "Strand/App/AppModel.swift").read_text(encoding="utf-8")
ble = (ROOT / "Strand/BLE/BLEManager.swift").read_text(encoding="utf-8")
dashboard = (ROOT / "StrandiOS/VITAE/VITAEPerformanceDashboard.swift").read_text(encoding="utf-8")
for fragment in (
    "protocolConnectionEnabled: false",
    "conectores de outras pulseiras e anéis não são iniciados",
):
    if fragment not in runtime:
        fail(f"AppModel não desativa o runtime legado: {fragment!r}")
for fragment in (
    "if protocolConnectionEnabled {",
    "guard protocolConnectionEnabled, central != nil else",
    "guard protocolConnectionEnabled else",
):
    if fragment not in ble:
        fail(f"BLEManager não protege inicialização/scan legado: {fragment!r}")
if "VWARCaptureManager()" in dashboard or "VWAR DIRETO" in dashboard:
    fail("dashboard ainda inicia ou expõe captura Bluetooth direta")

classifier = (ROOT / "Packages/StrandImport/Sources/StrandImport/HealthSourceClassifier.swift").read_text(encoding="utf-8")
for required in ("case gBand", "case strava", "case apple", "case other"):
    if required not in classifier:
        fail(f"classificador de origem ausente: {required}")
if re.search(r"case\s+garmin|garminConnect", classifier, re.IGNORECASE):
    fail("classificador ainda oferece Garmin")

terms = (ROOT / "Strand/App/Terms.swift").read_text(encoding="utf-8")
changelog = (ROOT / "Strand/System/AppChangelog.swift").read_text(encoding="utf-8")
if 'static let currentVersion = "1.2"' not in terms:
    fail("versão dos termos não é 1.2")
if 'static let currentVersion = "11.1.0"' not in changelog:
    fail("changelog interno não é 11.1.0")

design_path = ROOT / "Packages/StrandDesign/Sources/StrandDesign/Resources/Localizable.xcstrings"
design = json.loads(design_path.read_text(encoding="utf-8"))
missing_design = [
    key for key, item in design.get("strings", {}).items()
    if not item.get("localizations", {}).get("pt-BR", {}).get("stringUnit", {}).get("value")
]
if missing_design:
    fail(f"catálogo visual sem pt-BR: {', '.join(missing_design)}")

print("pt-BR verificado: interface refeita, G Band/Strava, privacidade e edições iOS 26.")
