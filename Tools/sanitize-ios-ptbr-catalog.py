#!/usr/bin/env python3
"""Remove integrações fora do escopo dos valores exibidos pelo catálogo iOS pt-BR.

As chaves inglesas continuam iguais porque são a API de localização usada pelo código compartilhado.
Somente os valores apresentados ao usuário são neutralizados, preservando especificadores de formato.
"""

from __future__ import annotations

import plistlib
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "StrandiOS/Resources/pt-BR.lproj/Localizable.strings"
BANNED = re.compile(
    r"\b(?:whoop|oura|garmin|fitbit|xiaomi|amazfit|huami|polar|wahoo|coros|suunto|zwift)\b",
    re.IGNORECASE,
)
FORMAT = re.compile(
    r"%(?:\d+\$)?[-+#0']*(?:\d+|\*)?(?:\.\d+|\.\*)?"
    r"(?:hh|h|ll|l|q|z|t|j)?(?:@|d|i|u|o|x|X|f|F|e|E|g|G|a|A|c|C|s|S|p|n|%)"
)


def format_specifiers(value: str) -> list[str]:
    result: list[str] = []
    for match in FORMAT.finditer(value):
        token = match.group(0)
        following = value[match.end():match.end() + 1]
        # `%HRmax` / `%FCmáx` are prose abbreviations, not printf placeholders.
        if len(token) == 2 and token[1].isupper() and following.isalpha():
            continue
        result.append(token)
    return result


with CATALOG.open("rb") as handle:
    entries: dict[str, str] = plistlib.load(handle)

changed = 0
for key, value in list(entries.items()):
    if not BANNED.search(value):
        continue
    specs = format_specifiers(value)
    if len(value) < 60 and not specs:
        replacement = "Recurso indisponível nesta edição VWAR"
    else:
        replacement = "Este recurso não faz parte da edição VWAR para iOS 26. Use G Band, Saúde da Apple ou Strava."
        if specs:
            replacement += " " + " ".join(specs)
    entries[key] = replacement
    changed += 1

with CATALOG.open("wb") as handle:
    plistlib.dump(entries, handle, fmt=plistlib.FMT_XML, sort_keys=True)

remaining = [value for value in entries.values() if BANNED.search(value)]
if remaining:
    raise SystemExit(f"valores proibidos restantes: {len(remaining)}")

print(f"Catálogo iOS pt-BR saneado: {changed} valores fora do escopo neutralizados.")
