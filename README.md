# Ion

A personal Tesla-style iOS app for a Hyundai IONIQ 5 on Bluelink (US).

- **API:** [BetterBlueKit](https://github.com/schmidtwmark/BetterBlueKit) (MIT), pinned by commit in `project.yml`.
- **Car artwork:** not in this repo. The images are made from studio photos of the car that aren't ours to share. Without them `Shared/CarView.swift` draws a paint-tinted fallback. To make your own, cut out front, side and rear studio photos (`tools/cutout.swift --full`), then run `tools/recolor.py --studio` (photo views per paint), `tools/sketch.py` (Sketch theme) and `tools/pastel.py` (Pastel theme). Paint ids are in `Shared/CarAppearance.swift`. `recolor.py`'s `STUDIO_MASKS` keeps glass, wheels and trim out of the paint, and its outlines are specific to one set of photos.
- **Themes:** Ion (seven colors), Sketch and Pastel, all following the system light/dark setting. The app icon can match the theme or use the Headlights or Tail Lights icon.
- **Live Activities:** climate warm-up/cool-down and charging sessions.
- **Color detection:** `Shared/AppearanceResolver.swift` scans the Bluelink enrollment response for color fields and calls NHTSA's VIN decoder for make, model, year and trim. If Bluelink reports no color, pick one in Settings. Settings → Diagnostics shows the raw response.
- **Speed:** commands update the UI right away. The app then polls Hyundai's cached status (which never wakes the car) until the car confirms. **Wake** forces a live poll, which is slow and rate-limited.
- **Extras:** Home and Lock Screen widgets, a Control Center lock toggle and climate button, and Siri/Shortcuts ("Lock my car with Ion"). Unlocking requires Face ID.

## Build

```bash
xcodegen generate && open Ion.xcodeproj
```

Signed with the Nathan Coleman individual team (`J3GLV5WWSZ`), using the app group `group.com.nathancoleman.ion`. Sign in with **demo** to try it without an account.
