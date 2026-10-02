"""One-shot helper: final copy polish for the intro ARB keys.

Run once with `python3 tool/finalize_intro_arb.py`, then delete this file.
Idempotent: values that already match are left untouched.
"""

import collections
import json

# Prototype `initPhases[].msg` strings, which carry the emoji the loading
# card shows, plus its exact completion line.
REFINEMENTS = {
    "app_en": {
        "introMessage": '"{message}"',
        "introPhaseSolarSystem": "Waking up the Sun... ☀️",
        "introPhaseSun": "Waking up the Sun... ☀️",
        "introPhasePlanets": "Checking the planets... 🌎",
        "introPhaseMoons": "Moon is getting ready... 🌕",
        "introPhaseCompanion": "Waking up your rocket buddy... 🚀",
        "introPhaseMissions": "Planning your missions... 🗺️",
        "introPhaseSounds": "Tuning the space sounds... 🔊",
        "introPhaseReady": "✨ YOUR UNIVERSE IS READY! ✨",
        "introCompleteTitle": "✨ YOUR UNIVERSE IS READY! ✨",
        "introStageSun": "Calibrating solar energy...",
    },
    "app_id": {
        "introMessage": '"{message}"',
        "introPhaseSolarSystem": "Membangunkan Matahari... ☀️",
        "introPhaseSun": "Membangunkan Matahari... ☀️",
        "introPhasePlanets": "Memeriksa planet-planet... 🌎",
        "introPhaseMoons": "Bulan sedang bersiap... 🌕",
        "introPhaseCompanion": "Membangunkan teman roketmu... 🚀",
        "introPhaseMissions": "Merencanakan misimu... 🗺️",
        "introPhaseSounds": "Menyetel suara antariksa... 🔊",
        "introPhaseReady": "✨ SEMESTAMU SUDAH SIAP! ✨",
        "introCompleteTitle": "✨ SEMESTAMU SUDAH SIAP! ✨",
    },
}

for locale, refinements in REFINEMENTS.items():
    path = f"packages/core/lib/src/l10n/arb/{locale}.arb"
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle, object_pairs_hook=collections.OrderedDict)
    changed = False
    for key, value in refinements.items():
        if data.get(key) != value:
            data[key] = value
            changed = True
    if changed:
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(data, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
    print(locale, "updated" if changed else "unchanged")
