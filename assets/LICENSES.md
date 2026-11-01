# Asset licenses

Every file under `assets/` (other than this file) MUST be listed here by its relative path with
its source and license. `scripts/check_asset_licenses.sh` fails CI otherwise.

| File | Source | License | Notes |
|------|--------|---------|-------|
| assets/sfx/button.wav | Synthesized by scripts/gen_sfx.py (stdlib sine/noise) | CC0-1.0 | own-made, ya-spark |
| assets/sfx/dash.wav | Synthesized by scripts/gen_sfx.py (stdlib sine/noise) | CC0-1.0 | own-made, ya-spark |
| assets/sfx/flap.wav | Synthesized by scripts/gen_sfx.py (stdlib sine/noise) | CC0-1.0 | own-made, ya-spark |
| assets/sfx/game_over.wav | Synthesized by scripts/gen_sfx.py (stdlib sine/noise) | CC0-1.0 | own-made, ya-spark |
| assets/sfx/hit.wav | Synthesized by scripts/gen_sfx.py (stdlib sine/noise) | CC0-1.0 | own-made, ya-spark |
| assets/sfx/orb.wav | Synthesized by scripts/gen_sfx.py (stdlib sine/noise) | CC0-1.0 | own-made, ya-spark |
| assets/sfx/pass.wav | Synthesized by scripts/gen_sfx.py (stdlib sine/noise) | CC0-1.0 | own-made, ya-spark |
| assets/sfx/perfect_1.wav | Synthesized by scripts/gen_sfx.py (stdlib sine/noise) | CC0-1.0 | own-made, ya-spark |
| assets/sfx/perfect_2.wav | Synthesized by scripts/gen_sfx.py (stdlib sine/noise) | CC0-1.0 | own-made, ya-spark |
| assets/sfx/perfect_3.wav | Synthesized by scripts/gen_sfx.py (stdlib sine/noise) | CC0-1.0 | own-made, ya-spark |
| assets/sfx/perfect_4.wav | Synthesized by scripts/gen_sfx.py (stdlib sine/noise) | CC0-1.0 | own-made, ya-spark |
| assets/sfx/perfect_5.wav | Synthesized by scripts/gen_sfx.py (stdlib sine/noise) | CC0-1.0 | own-made, ya-spark |
| assets/sfx/perfect_6.wav | Synthesized by scripts/gen_sfx.py (stdlib sine/noise) | CC0-1.0 | own-made, ya-spark |
| assets/sfx/perfect_7.wav | Synthesized by scripts/gen_sfx.py (stdlib sine/noise) | CC0-1.0 | own-made, ya-spark |
| assets/sfx/shatter.wav | Synthesized by scripts/gen_sfx.py (stdlib sine/noise) | CC0-1.0 | own-made, ya-spark |
| assets/voice/awesome.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/better_than_the_best.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/careful.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/excellent.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/fantastic.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/game_over.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/game_over_02.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/get_ready.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/go.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/great.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/incredible.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/nice.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/revived.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/smashed_it.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/unbelievable.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/well_done.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/well_done_02.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/you_did_it.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |

Store graphics and launcher icons (not under `assets/`, drawn by `scripts/gen_store_art.py`, own work, CC0-1.0):
`store/google-play/graphics/icon-512.png`, `store/google-play/graphics/feature-graphic-1024x500.png`,
`android/app/src/main/res/mipmap-*/ic_launcher.png`. No third-party material.

Format for an asset row: `| assets/sfx/pop.ogg | https://example.org/pop | CC0-1.0 | by Jane Doe |`
