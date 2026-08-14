# String Art Studio

A single-file, zero-build web app that does two things:

1. **String art generator** — turns a photo into the sequence of pins the thread has to pass through, using a greedy chord-selection algorithm. This is the view the page opens on.
2. **Template PDF** — draws the drilling/nailing template from just two numbers, the **number of points** and the **circle radius in cm**. The output is a print-at-100% PDF with a black circle, red points and a red number next to every point.

Everything runs in the browser. Nothing is uploaded anywhere.

## Running it

Open `index.html` in a browser. That's it — there is no build step, no server and no dependency to install.

To serve it over HTTP instead (for example to publish it on GitHub Pages), any static host works:

```bash
python3 -m http.server 8000
# then open http://localhost:8000
```

React, jsPDF, three.js and the flag icons are loaded from CDNs, so the first load needs a network connection.

## Languages

The interface ships in **English, Portuguese, French, Spanish, Italian and German**, switchable from the selector in the header. Portuguese is the default. Translations live in the `window.I18N` object near the top of `index.html`; adding a language means adding one entry there and one line to the `languages` array in `LanguageSelector`.

## String art generator

Load a photo and it appears in colour, so you can choose the framing first: zoom with the mouse wheel or the `−` / `+` buttons, drag the image to reposition it, and press **Fit** to go back to the largest square that fits. Zooming below 100% shows the whole photo inside the circle and leaves the surrounding area white, which the thread simply ignores. The outlined circle marks how far the thread can reach.

Pressing **Generate** freezes that framing: the image is converted to greyscale, masked to the circle, and only then does the preview turn grey. The solver runs in a Web Worker:

- start at pin 0;
- for every candidate pin at least `minimum pin distance` away, sum the remaining darkness along that chord;
- keep the best one, subtract `line weight` from the error image along it, and repeat;
- the last 20 pins are skipped to avoid the thread bunching up in one spot.

| Parameter | Default | Effect |
| --- | --- | --- |
| Number of pins | 288 | Follows the template point count unless unticked |
| Number of lines | 3000 | More lines, darker and more detailed result |
| Line weight | 20 | How much darkness one thread removes; higher means fewer overlaps |
| Minimum pin distance | 20 | Blocks very short threads between neighbouring pins |
| Working resolution | 500 px | Solver resolution; higher is slower and sharper. Read when you press Generate, so it can be changed between runs |

The thread colour, wood colour and board shape belong to the 3D preview and survive regenerating, so you can try different parameters without losing them.

Before solving, the worker rasterises every chord once into a single flat buffer, so the search only has to add up bytes. A run of 3000 lines over 288 pins takes roughly a third of a second. That buffer grows with both the pin count and the working resolution, so extreme combinations (around 1000 pins at 1200 px) are refused up front with a message rather than exhausting the tab's memory.

Results can be exported as the raw pin sequence (`.txt`), a preview `.png`, or a multi-page **instructions PDF** listing every step as `from » to`. The estimated thread length uses the radius set on the template tab, so both tabs describe the same physical piece.

## 3D preview

Once a sequence exists, a **3D preview** shows what the finished piece would look like on a board. Drag to turn it, scroll to move closer. The nails are black and always drawn as small tapered cylinders; you can pick the thread colour and the wood colour, and switch the support between a rectangular and a round board. Either way the board is slightly wider than the drawing, so the nail circle always sits inside it.

The round button in the top-right corner of the view blows it up to fill almost the whole window, which is where the individual threads become readable. Press it again, hit `Escape`, or click outside the view to come back. The card keeps its height while the view is expanded, so nothing on the page shifts around.

It is drawn with [three.js](https://threejs.org/), loaded from a CDN as a plain global script so the file still needs no build step. The threads are one `LineSegments` buffer and the nails a single `InstancedMesh`, which keeps even a 20 000-line piece interactive. Threads climb gradually from just above the board to the nail heads, so the winding order stays visible, and they are drawn at the same opacity as the flat preview, so the shading comes from how many of them overlap rather than from each one being dark. The scene only redraws when something actually changes.

## Template PDF

| Input | Meaning |
| --- | --- |
| Number of points | Nails/pins spread evenly around the circle |
| Circle radius (cm) | Radius of the ring the points sit on |
| Page size | `Auto` picks the smallest ISO page that fits, or choose A4–A0 / custom mm |
| Point 0 position | Which clock position the numbering starts from |
| Numbering direction | Clockwise or counter-clockwise |
| Number every N points | Skip labels when the points get too close to read |

The summary panel reports the diameter, the drawing size, the circumference and the **spacing between points**, which is the number you actually need when marking the board. A warning appears when the drawing does not fit the chosen page, or when the numbers are close enough to overlap.

Both **PDF** and **SVG** can be downloaded. The PDF is vector-only and prints at exactly the requested physical size — print at 100% / "actual size", not "fit to page".

### How the drawing is proportioned

The layout is defined in *design units* where the circle radius is exactly 90 u, so a template looks identical at any physical size. Every other measure is a fixed ratio of the radius:

| Element | Design units | As a ratio of the radius |
| --- | --- | --- |
| Circle radius | 90 | R |
| Circle stroke | 1 | R / 90 |
| Point dot radius | 0.5 | R / 180 |
| Number font size | 2 | R / 45 |
| Number offset (outwards) | 4 | 4R / 90 |
| Number offset (sideways) | 1 | R / 90 |
| Square frame half-side | 96 | 96R / 90 |

The numbers are set in Times and rotated to read radially outwards, matching the original template this project was modelled on. Because jsPDF misplaces text when `align`/`baseline` are combined with `angle`, the baseline origin is computed by hand from the text advance width and the Times x-height.

## Project layout

```
index.html   the entire application
README.md    this file
LICENSE
```
