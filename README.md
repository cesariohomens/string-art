# String Art Studio

A single-file, zero-build web app that does four things:

1. **String art generator** — turns a photo into the sequence of pins the thread has to pass through, using a greedy chord-selection algorithm. This is the view the page opens on.
2. **Template PDF** — draws the drilling/nailing template from just two numbers, the **number of points** and the **circle radius in cm**. The output is a print-at-100% PDF with a black circle, red points and a red number next to every point.
3. **Template STL** — models a printable ring carrying one nail per point, from those same two numbers, cuts it into arcs that clip together if it is bigger than the print bed, and exports it as an STL or a ZIP of STLs.
4. **Winding machine** — writes the job for the machine in [`machine/`](machine/), which strings the picture itself. Download the `.gcode`, or send it straight to the machine and drive it from the same page.

Everything runs in the browser. Nothing is uploaded anywhere, except to a machine you tell it to talk to.

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

The renderer, the lights, the orbit camera and the maximise button live in a `useStage3D` hook that the nail ring preview reuses, so both views behave the same way and there is only one place to fix.

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

## Template STL

Instead of drilling a board you can print the circle. This tab builds a flat band with a nail standing on every point and exports it as a **binary STL in millimetres**, which any slicer opens at the right size.

It reads the same **number of points** and **circle radius** as the template tab, so the printed ring and the printed template describe the same circle. The band straddles the point circle rather than sitting inside or outside it, so the thread still runs at exactly the requested radius.

| Input | Default | Meaning |
| --- | --- | --- |
| Nail height | 12 mm | How far a nail stands above the band |
| Nail diameter | 3 mm | Measured across the corners of the printed prism |
| Nail tip | straight | Straight, a shrimp curl, or tapered 30% wider |
| Ring width | 10 mm | Radial width of the band |
| Ring thickness | 4 mm | Height of the band itself |
| Ring segments | 1 | How many arcs to cut the ring into |
| Joint clearance | 0.25 mm | Play left between a tab and its slot |
| Numbered snap-off tags | off | A numbered pointer at every nail |

### How the nails end

Thread wraps the outer face of a nail and is pulled towards the centre of the circle, so the one way a finished loop can escape is upwards, over the tip. **Nail tip** offers three ends, and the second and third both work by making the top harder to leave than the shaft:

- **Straight** is a plain post, quickest to print and the lightest of the three. Use it when the nails are tall enough that the thread never reaches the top anyway.
- **Shrimp curl** climbs about two thirds of the height and then turns 100° outwards, ending in a tip that hangs over the shaft — roughly 5 mm past the nail axis at the default size — with the thread caught in the crook. The turn tapers to 72% of the shaft, which is what gives it the shrimp outline. It reaches its full height at the crown of the bend rather than at the tip, so a curl stands exactly as tall as the straight nail it replaces, and it takes no extra room between neighbours because it bends radially rather than along the ring. It does overhang, so print it with supports.
- **Tapered 30% wider** grows steadily from the base to a tip 30% thicker, a cone the loop cannot ride up. It prints without supports, since the flare is only a few tenths of a millimetre off vertical, but the wide end is what the neighbouring nails have to make room for: the reported gap between nails is measured there, and on a crowded ring the tips will merge before the bases would.

The gap between nails, and the warning that goes with it, always refer to the widest end of whichever tip is chosen, and the summary adds the tip diameter for a cone or the overhang for a curl. All three shapes work on a ring that is cut into arcs and carries numbered tags.

### Cutting the ring into arcs

A 28 cm radius gives a 57 cm ring, which no ordinary printer will take in one piece, so **ring segments** cuts it into that many arcs. Leave it at 1 and the ring comes out whole.

Each cut lands in the middle of a nail gap, never on a nail, and leaves a **puzzle joint**: the arc ahead of the cut ends in a tab with a narrow neck and a round head that swells past it, and the arc behind it ends in the matching slot, whose two prongs close over the head. Pulling two arcs apart along the ring is blocked by the head; they only come apart the way they went together. Since the joint has to fit between two nails, its length is worked out from the room left there — roughly 1.7 mm at 288 points and a 28 cm radius, up to 8 mm on a sparser ring. **Joint clearance** is the gap left between tab and slot, 0.25 mm by default; raise it if your printer runs tight. That gap is measured perpendicular to the profile rather than shifted sideways, so it stays even where the head flares out.

With the ring cut up, the button hands over a **ZIP** instead of a single STL, holding one file per arc named `…-PART_01_OF_10.stl` and so on. Each part is turned so its arc straddles the x axis and centred on the origin, which is where a slicer wants it, and the summary reports the **largest part** as it would sit on the bed so you can tell at a glance whether it fits.

### Numbered snap-off tags

The printed band carries no numbers, so **numbered snap-off tags** adds a pointer at every nail with its number raised on it, reading outwards along the radius exactly as the numbers on the paper template do. Each tag hangs off the outer wall on a stub about 2 mm wide and 1.6 mm thick: strong enough to survive printing, easy to snap or cut off once the picture is finished.

Digits are drawn as seven raised strokes rather than typeset, which needs no font and prints cleanly. Their size follows the room between neighbouring nails, so on a crowded ring they shrink; below about 2.2 mm tall the tab says so and suggests either fewer points or no tags.

### The summary and its warnings

The summary reports the outer diameter, total height, point spacing, gap between nails, the tip diameter or curl overhang when the nails are shaped, number of parts, the size of the largest part, the joint length once the ring is cut, and the **material volume** measured off the mesh a slicer will read. Warnings appear when the nails are close enough to merge, when no joint fits between them, when the tags are too small to read, and when the largest part still will not fit a 25 cm bed.

The 3D preview turns and zooms exactly like the one on the generator tab, including the maximise button, and the part can be recoloured to match the filament you intend to use. Every other arc is drawn a shade darker, because at the size the whole ring is shown the joints themselves are a hairline.

### How the solid is built

- Everything is a closed solid in its own right: the band, each nail, the tab, the two prongs of a slot, and each tag and stroke. Solids that belong to the same part overlap rather than touch, so a slicer reads them as one body and never meets two faces in the same place.
- A nail is a tube through a handful of circular sections, which is what lets one routine print all three tips: two sections for a post, a wider one on top for a cone, and eleven around the bend for a curl. Each section carries its own radius and the two axes its circle is drawn on, kept perpendicular to the path, and the bend radius is held above the nail's own so the inside of a curl cannot fold through itself.
- Curves are emitted as polygons whose corners touch the nominal circle: 12 faces per nail, and enough steps for a facet of about 4 mm. The slot is the tab grown outwards by the clearance, walked at the same distances along the profile, so the two mate by construction.
- Seams close on exactly the same coordinates, so every mesh is watertight, every directed edge is used once, and every facet is wound outwards. The reported volume counts the overlaps twice and so runs about a percent over the truth.
- The preview and the exported files are built from the same triangle lists, so what you turn around on screen is what gets sliced.

## Winding machine

The fourth tab writes jobs for the machine in [`machine/`](machine/): a
turntable that carries the board, a guide on a rail that reaches over it, and an
ESP32 that runs the whole thing off a page it serves itself. The machine is
described, down to its wiring and its g-code, in
[`machine/PROTOCOL.md`](machine/PROTOCOL.md); how to build one is in
[`machine/README.md`](machine/README.md).

The tab takes the sequence from the generator — which is why the sequence now
lives in the app rather than in the generator tab, and survives switching tabs —
or a `.txt` saved from an earlier run. Alongside the usual number of points and
radius it asks for the few things only the machine knows: the height the thread
is laid at, the diameter of the nails, the radius of the guide's tip, and how
far the guide can reach.

| Input | Default | Meaning |
| --- | --- | --- |
| Wrap height | 6 mm | Where the thread is laid on the shank, measured from the board |
| Nail diameter | 3 mm | The same nails the STL tab prints |
| Guide tip radius | 1.1 mm | The outside of the eyelet, which has to pass between two nails |
| Orbit radius | worked out | How far the eyelet stays from the nail while it goes round it |
| Machine reach | 300 mm | How far the guide gets from the middle of the turntable |
| Travel and wrap feeds | 4200 / 1200 mm/min | Measured at the eyelet, so a job runs at the same speed on any size of machine |

The orbit is chosen for you: it has to clear the nail it is going round without
reaching the next one along, which on a 288-point 28 cm ring leaves a window
between 2.6 and 4.6 mm. When no radius satisfies both — nails closer than about
5.5 mm — the tab refuses the job and says which of the three numbers to change,
rather than letting the machine drive into the ring.

A job is a header stating the ring and then one line per nail, so a
3000-wrap picture is about 30 kB rather than several megabytes of arcs, and the
same file runs on a machine of any size. **Download .gcode** saves it;
**Send to the machine** posts it to `printer.local` (or whatever address you
give it) with the user and password, after which the same card shows what the
machine is doing and offers start, pause and stop. The summary estimates how
long it will take, which for a dense picture is worth knowing before you press
anything.

Opened over `https`, a browser will not let the page talk to a machine that
speaks `http`; the tab says so. Open the app over `http`, from a file, or from
the machine itself, which serves this very page out of its own flash.

## Project layout

```
index.html   the entire application
machine/     the winding machine: protocol, bill of materials, hardware, firmware
README.md    this file
LICENSE
```
