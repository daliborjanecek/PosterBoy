# PosterBoy

A minimal Swift Package for AR image overlays. Detects reference images in the real world and projects static images or looping videos onto them.

Built on **ARKit + RealityKit**. Zero external dependencies.

## Requirements

- iOS 16+
- Xcode 16+
- Device with ARKit support (does not work in Simulator)

---

## 1. Create a New Xcode Project

1. **File → New → Project → App**
2. Interface: **SwiftUI**, Language: **Swift**
3. Name your project (e.g. `PosterDemo`)
4. Save and open

## 2. Add PosterBoy Package

1. **File → Add Package Dependencies…**
2. Paste the repository URL:
   ```
   https://github.com/daliborjanecek/PosterBoy.git
   ```
3. **Add Package**, confirm adding the `PosterBoy` library to your target

## 3. Set Up AR Resources in Xcode

1. Open **Assets.xcassets**
2. Right-click → **AR and Textures → New AR Resource Group**
3. Name the group `AR Resources` (or use a custom name — pass it via the `resourceGroup:` parameter)
4. Drag your reference images into the group
5. **Important** — for each image, set in the inspector:
   - **Name**: this is the string you'll use as the `anchor:` parameter in code
   - **Size**: physical size in meters (width × height) — the overlay will match this exactly

## 4. Info.plist

Add the camera usage description:

```
Privacy - Camera Usage Description: This app uses the camera for augmented reality.
```

In Xcode 15+: Target → Info → Custom iOS Target Properties → **+** → `NSCameraUsageDescription`

## 5. Usage

### Basic Image Overlay

```swift
import SwiftUI
import PosterBoy

struct ContentView: View {
    var body: some View {
        PosterView(content:
            .image(
                anchor: "movie-poster",
                overlay: UIImage(named: "hero-image")!
            )
        )
        .ignoresSafeArea()
    }
}
```

### Video Overlay

```swift
PosterView(content:
    .video(
        anchor: "movie-poster",
        overlay: Bundle.main.url(forResource: "trailer", withExtension: "mp4")!
    )
)
.ignoresSafeArea()
```

### Multiple Overlays

```swift
PosterView(contents: [
    .image(anchor: "poster-lobby", overlay: UIImage(named: "lobby-art")!),
    .video(anchor: "poster-screen", overlay: trailerURL),
    .image(anchor: "poster-exit", overlay: UIImage(named: "exit-promo")!)
])
.ignoresSafeArea()
```

### Environment Lighting

```swift
// lit: true — overlay reacts to real-world lighting estimated by ARKit
PosterView(content:
    .image(anchor: "painting", overlay: UIImage(named: "detail")!, lit: true)
)
.ignoresSafeArea()
```

> **Note:** `lit` only applies to image overlays. `VideoMaterial` in RealityKit is always unlit.

### Per-Anchor Callbacks

```swift
PosterView(contents: [
    .image(anchor: "poster1", overlay: myImage)
        .onDetected { print("Poster 1 detected") }
        .onLost { print("Poster 1 lost") },
    .video(anchor: "poster2", overlay: videoURL)
        .onDetected { print("Video poster detected") }
])
.ignoresSafeArea()
```

### Global Callbacks

```swift
PosterView(contents: posters)
    .onAnchorDetected { name in
        print("Detected anchor: \(name)")
    }
    .onAnchorLost { name in
        print("Lost anchor: \(name)")
    }
    .ignoresSafeArea()
```

### Full Example — Exhibition App

```swift
struct ExhibitionView: View {
    @State private var activeAnchors: Set<String> = []
    
    let posters: [PosterContent] = [
        .image(anchor: "mona-lisa", overlay: UIImage(named: "mona-detail")!),
        .video(anchor: "starry-night", overlay: Bundle.main.url(forResource: "starry-timelapse", withExtension: "mp4")!)
    ]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            PosterView(contents: posters)
                .onAnchorDetected { name in
                    withAnimation { activeAnchors.insert(name) }
                }
                .onAnchorLost { name in
                    withAnimation { activeAnchors.remove(name) }
                }
                .ignoresSafeArea()
            
            if !activeAnchors.isEmpty {
                Text("Tracking: \(activeAnchors.joined(separator: ", "))")
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 40)
            }
        }
    }
}
```

---

## API Reference

### `PosterContent`

| Factory Method | Description |
|---|---|
| `.image(anchor:overlay:lit:)` | Static image overlay. `lit: true` = reacts to AR environment lighting. Default `false`. |
| `.video(anchor:overlay:lit:)` | Looping video (autoplay, muted). `lit` is ignored — `VideoMaterial` is always unlit. |

| Modifier | Description |
|---|---|
| `.onDetected { }` | Called when this specific anchor is detected |
| `.onLost { }` | Called when this specific anchor loses tracking |

### `PosterView`

| Initializer | Description |
|---|---|
| `init(content:resourceGroup:)` | Single overlay |
| `init(contents:resourceGroup:)` | Array of overlays |

| Modifier | Description |
|---|---|
| `.onAnchorDetected { name in }` | Global callback for any anchor detection |
| `.onAnchorLost { name in }` | Global callback for any anchor loss |

`resourceGroup` — name of the AR Resource Group in Xcode Assets. Default: `"AR Resources"`.

---

## How It Works

1. `PosterView` creates an `ARView` and starts an `ARImageTrackingConfiguration`
2. Only reference images matching the provided `anchor` names are tracked
3. On detection, an `AnchorEntity` is created with a `ModelEntity` (plane mesh)
4. Plane size = physical size of the reference image set in AR Assets
5. Material: `UnlitMaterial` (image default) / `PhysicallyBasedMaterial` (image with `lit: true`) / `VideoMaterial` (video, always unlit)
6. ARKit handles orientation automatically — works on walls, floors, and tables

## License

MIT
