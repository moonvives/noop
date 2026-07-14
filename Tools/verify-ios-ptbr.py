#!/usr/bin/env python3
"""Falha o build quando a experiência iOS 26 deixa de ser integralmente pt-BR.

O verificador é intencionalmente local: não envia catálogo, código ou texto a serviços externos.
"""

from __future__ import annotations

import plistlib
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

ACTIVE_SURFACES = [
    ROOT / "StrandiOS/App/RootTabView.swift",
    ROOT / "StrandiOS/VITAE/VITAEPerformanceDashboard.swift",
    ROOT / "StrandiOS/VITAE/VWARLoopLife26Experience.swift",
    ROOT / "StrandiOS/VITAE/VWARPortugueseGates.swift",
    ROOT / "StrandiOSWidgets/NOOPWidget.swift",
    ROOT / "StrandiOSWidgets/NOOPLiveActivity.swift",
    ROOT / "StrandiOSShared/LiveActivityAttributes.swift",
]

# Frases que já vazaram para a interface em versões anteriores. Procuramos somente literais Swift,
# portanto comentários técnicos não derrubam o build.
BANNED_UI_LITERALS = {
    "Today",
    "Trends",
    "Sleep",
    "More",
    "Done",
    "Open",
    "Support",
    "Profile",
    "About you",
    "Bring your history",
    "Save & Continue",
    "Continue",
    "Recovery",
    "Effort",
    "Rest",
    "Charge",
    "Battery",
    "Live HR",
}


def fail(message: str) -> None:
    print(f"ERRO pt-BR: {message}", file=sys.stderr)
    raise SystemExit(1)


def swift_literals(text: str) -> set[str]:
    # Suficiente para detectar os rótulos curtos acima; evita interpretar comentários e não pretende
    # substituir o parser Swift.
    without_comments = re.sub(r"//.*?$|/\*.*?\*/", "", text, flags=re.MULTILINE | re.DOTALL)
    return set(re.findall(r'"((?:\\.|[^"\\])*)"', without_comments))


for path in ACTIVE_SURFACES:
    if not path.is_file():
        fail(f"superfície obrigatória ausente: {path.relative_to(ROOT)}")
    literals = swift_literals(path.read_text(encoding="utf-8"))
    leaked = sorted(BANNED_UI_LITERALS.intersection(literals))
    if leaked:
        fail(f"{path.relative_to(ROOT)} contém rótulos em inglês: {', '.join(leaked)}")

project = (ROOT / "project.yml").read_text(encoding="utf-8")
required_project_fragments = [
    'NOOPiOS:',
    'deploymentTarget: "26.0"',
    'MARKETING_VERSION: "10.0.0"',
    'CURRENT_PROJECT_VERSION: "173"',
    'CFBundleDevelopmentRegion: pt-BR',
    '- pt-BR',
    'TARGETED_DEVICE_FAMILY: "1,2"',
]
for fragment in required_project_fragments:
    if fragment not in project:
        fail(f"project.yml não contém {fragment!r}")

with (ROOT / "StrandiOS/Resources/Info.plist").open("rb") as handle:
    info = plistlib.load(handle)

if info.get("CFBundleDevelopmentRegion") != "pt-BR":
    fail("CFBundleDevelopmentRegion do aplicativo não é pt-BR")
if info.get("CFBundleLocalizations") != ["pt-BR"]:
    fail("CFBundleLocalizations do aplicativo deve conter apenas pt-BR")

for key in (
    "NSBluetoothAlwaysUsageDescription",
    "NSHealthShareUsageDescription",
    "NSHealthUpdateUsageDescription",
    "NSLocationWhenInUseUsageDescription",
):
    value = info.get(key, "")
    if not isinstance(value, str) or not value.startswith("O VWAR Loop Life"):
        fail(f"{key} não está em português do Brasil")

all_active_text = "\n".join(path.read_text(encoding="utf-8") for path in ACTIVE_SURFACES)
for required in (
    "VWARPortugueseOnboarding",
    "VWARPortugueseTermsGate",
    "VWARTrendsView",
    "VWARSleepIntelligenceView",
    "VWARSourcesView",
    "Garmin Connect",
    "G Band",
):
    if required not in all_active_text:
        fail(f"experiência obrigatória ausente: {required}")

if "VITAE One" in all_active_text or "VITAE One" in project:
    fail("o nome legado VITAE One ainda aparece na edição iOS")

print("pt-BR verificado: interface ativa, permissões, versão, dispositivo e sistema mínimo.")
