# Google Play store assets (drafts)

- `listing.md` – title, short and full description (limits: 30 / 80 / 4000 chars).
- `privacy_policy.md` – draft; must be hosted at a public URL and linked in Play Console.
- `data_safety.md` – draft answers for the Data safety form.

Graphics are generated in code by `scripts/gen_store_art.py` (needs Pillow). Files: `icon-512.png`, `feature-graphic-1024x500.png`, `screenshot-1..4.png` (stylized mock scenes; replace with real device captures before release if desired). Icon 512x512, feature graphic 1024x500, screenshots) are produced by the asset agent
and must be recorded in `assets/LICENSES.md` if they use third-party material.
