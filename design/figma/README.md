# Figma source

Figma file: https://www.figma.com/design/XzRIMOQaZ2idUztQPhRcZC (FreshKeep — SE4041 UI Design)

Pages
1. **Style Guide & Components** — logo, colour tokens (light/dark), type scale, design principles,
   components: Freshness Ring (4 states), Button (Primary/Soft), Filter Chip, Pantry Row,
   Stat Tile, Tab Bar, Scan Match Row.
2. **App Screens & Flow** — iPhone screens built from the component instances.
3. **visionOS Prototype** — spatial window, volumetric fridge and immersive timeline.

Notes
* SF Pro Rounded / SF Symbols cannot be rendered by Figma's cloud renderer, so the file uses
  **Nunito** and **Material Symbols Rounded** as visual stand-ins. The app uses the system
  fonts (`.rounded` design) and SF Symbols.
* The Figma Starter plan allows 3 pages and a single variable mode, so light/dark tokens are
  two variable groups (`light/*`, `dark/*`) in one collection.
* `screens-batch-2.js` is the Plugin API script for screens 04–10 (run with the Figma MCP
  `use_figma` tool or the Scripter plugin).
