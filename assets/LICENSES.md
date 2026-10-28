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

Store graphics and launcher icons (not under `assets/`, drawn by `scripts/gen_store_art.py`, own work, CC0-1.0):
`store/google-play/graphics/icon-512.png`, `store/google-play/graphics/feature-graphic-1024x500.png`,
`android/app/src/main/res/mipmap-*/ic_launcher.png`. No third-party material.

Format for an asset row: `| assets/sfx/pop.ogg | https://example.org/pop | CC0-1.0 | by Jane Doe |`
