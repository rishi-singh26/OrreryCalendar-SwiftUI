<p align="center">
  <picture>
    <img src="Assets/Primary.png" width="140" style="border-radius: 28px;" alt="Orrery app icon">
  </picture>
</p>

<h1 align="center">Orrery</h1>
<p align="center">A calm, on-device orrery for exploring where the planets and Moon stood on any day.</p>

---

<p align="center">
  <img src="Assets/AppLook-2.png" alt="Orrery app screenshots" width="100%">
</p>

<p align="center">
  <img src="Assets/AppLook.png" alt="Orrery app screenshots" width="100%">
</p>

<p align="center">
  <img src="Assets/AppLook-1.png" alt="Orrery app screenshots" width="100%">
</p>

## About

Orrery draws the Sun, the eight planets, and the Moon's phase for any date you choose — past, present, or centuries into the future — entirely on your device. Scrub a timeline, jump to a date, and watch the solar system rearrange itself in real time.

All positions are computed locally with a vendored copy of [Astronomy Engine](https://github.com/cosinekitty/astronomy), so there's no network call, no server, and no tracking involved in showing you the sky.

## Features

- **Live orrery chart** — the Sun and 8 planets plotted by true orbital distance and ecliptic longitude, redrawn as you move through time.
- **Planet detail** — tap into any planet for an interactive 3D model you can rotate and zoom, with an optional date that stays synced to the main timeline.
- **Moon phase discs** — Northern and Southern hemisphere views with illumination percentage, plus an optional Moon size control.
- **Scrub timeline** — drag, scroll, or use the trackpad/scroll wheel to glide through days, with month/year tick marks (adjustable boundary ticks), haptic feedback, and a graphical date picker for jumping straight to a date.
- **Auto Play** — let the date advance on its own, with adjustable speed (days, weeks, or months per second), direction, and control over what happens when you change the date manually.
- **Save & share** — bookmark interesting dates, sync them across your devices via iCloud, and share them as a polaroid-style card.
- **Customizable display** — toggle orbit rings, planet labels, the Sun halo, and the Moon size control; switch between system, light, and dark appearance.
- **Alternate app icons** — pick from several icon styles (iOS / iPadOS).
- **Adjustable date range** — cache anywhere from ±5 to ±100 years of positions, computed once and stored locally, and extend the range on demand.
- **Adaptive SwiftUI app** — one codebase with layouts tuned for iPhone, iPad, and Mac.

## Built with

- **SwiftUI** for the interface, with layouts that adapt between compact and large screens.
- **SwiftData** for persisting cached planetary data and saved dates.
- **[Astronomy Engine](https://github.com/cosinekitty/astronomy)** (vendored, MIT licensed) for on-device astronomical calculations — see [`NOTICES.md`](NOTICES.md) for details.

## Requirements

- Xcode 26 or later
- iOS / iPadOS 18.6+ or macOS 15.6+

## Getting started

```bash
git clone https://github.com/rishi-singh26/OrreryCalendar-SwiftUI.git
cd OrreryCalendar-SwiftUI
open Orrery.xcodeproj
```

Select the `Orrery` scheme and run it on your simulator or device of choice.

## Project structure

```
Orrery/
├── App/          # App entry point
├── Astronomy/    # Geometry and shape math for the chart
├── Data/         # SwiftData models, caching, and the Astronomy Engine bridge
├── Shared/       # Cross-platform utilities and small reusable views
├── Theme/        # Colors, appearance, and app storage keys
└── Views/        # Screens and UI components
AstronomyEngine/  # Vendored Astronomy Engine (Swift package wrapping the C library)
```

## Acknowledgments

Planetary and lunar positions are computed using [Astronomy Engine](https://github.com/cosinekitty/astronomy) by Don Cross. See [`NOTICES.md`](NOTICES.md) for the full third-party notice.

## License

Orrery is released under the [MIT License](LICENSE). Third-party components retain their own licenses — see [`NOTICES.md`](NOTICES.md).
