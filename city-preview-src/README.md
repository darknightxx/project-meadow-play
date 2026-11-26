# Meadowfall city exploration preview

Godot 4.4.1 Compatibility, single-threaded Web export. A separate test scene: it does not change `/test-main/`, the live server, accounts, currencies, or existing map files.

The layout reads the actual Willowbrook 160×160 map, height samples, spawn `(80,83)`, 19 NPC anchors, and five portal rectangles/destinations pinned at source commit `6d7b4f2d7276a4ebd09ac840bd615c0f64f23c63`. Original navigation is retained with two explicit local changes: the smaller fountain basin and the chapel doorway/interior. NPC anchors are retained as data; characters and quest logic are not included in this scene. Portal markers identify the original destinations without server travel.

Buildings and props are selected from the existing public game packs at `0f354850b474a1be5a714fec3a40f9d0c7705e9a`, with size and Git blob hashes checked before extraction. Thai buildings and their matching textures are bundled from the pinned source revision; the four locally available texture hashes match GitHub exactly and the sala texture was fetched from that revision. `preview-manifest.json` records the actual model paths and triangle counts. Textures use a fixed 512px texture budget (layout mask 1024px), with mipmaps, lossless PNG import, and no runtime quality switching. Original source assets are not modified. The lotus fountain, interior walls, prayer mats, and seated statue study are newly authored preview geometry, not purchased assets.

Controls: WASD to walk, drag the scene to look, or use the touch joystick. Native shortcuts: 1 overview, 2 walk, 3 interior, E pray. Moving cancels prayer. The donation dialog uses 100 temporary demonstration coins and explicit confirmation; it is unrelated to account currency and real money.

Build pipeline:

1. `fetch_packs.py` downloads and validates the published asset packs.
2. Godot runs `probe/prepare.gd` with absolute pack and game directories to extract selected reusable resources.
3. Import, navigation audit, and four actual engine renders.
4. Export using the matching Godot 4.4.1 web template; `finish_web.py` adds Thai HTML controls and checks the 20MiB PCK limit.
5. Playwright checks actual WebGL scene loading, keyboard movement, fountain collision, donation confirm/cancel, prayer cancellation, landscape/portrait UI, and joystick release. WebKit emulation is reported separately.

CI screenshots are real engine/browser output. Native rendering and desktop/mobile emulation do not certify frame rate, memory stability, or Safari compatibility on physical devices. Full MMORPG integration, server donation rules, character prayer animation, and real-device profiling remain separate integration work.
