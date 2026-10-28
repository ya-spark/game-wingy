# Asset licenses

Every file under `assets/` (other than this file) MUST be listed here by its relative path with
its source and license. `scripts/check_asset_licenses.sh` fails CI otherwise.

| File | Source | License | Notes |
|------|--------|---------|-------|
| _none_ | | | No binary files are bundled under `assets/`; the game draws everything in code and ships no sound files (no audio package is in use). |

Format for an asset row: `| assets/sfx/pop.ogg | https://example.org/pop | CC0-1.0 | by Jane Doe |`

## Generated graphics outside `assets/`

All drawn procedurally by `scripts/gen_store_art.py` (Pillow), original work, no third-party art, fonts or names. License: project's own (all rights reserved by the owner).

| File | Source | License | Notes |
|------|--------|---------|-------|
| store/google-play/icon-512.png | scripts/gen_store_art.py | own | Play icon |
| store/google-play/feature-graphic-1024x500.png | scripts/gen_store_art.py | own | Play feature graphic |
| store/google-play/screenshot-1.png .. screenshot-4.png | scripts/gen_store_art.py | own | stylized 1080x1920 mock scenes, not device captures |
| android/app/src/main/res/mipmap-*/ic_launcher.png | scripts/gen_store_art.py | own | launcher icons |
