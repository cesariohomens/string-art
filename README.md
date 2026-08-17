# String Art Studio

A single-file, zero-build web app that does four things:

1. **String art generator** — turns a photo into the sequence of pins the thread has to pass through, using a greedy chord-selection algorithm. This is the view the page opens on.
2. **Template PDF** — draws the drilling/nailing template from just two numbers, the **number of points** and the **circle radius in cm**. The output is a print-at-100% PDF with a black circle, red points and a red number next to every point.
3. **Template STL** — models a printable ring carrying one nail per point, from those same two numbers, cuts it into arcs that clip together if it is bigger than the print bed, and exports it as an STL or a ZIP of STLs.
4. **Printer G-code** — writes the whole picture out as G-code for an ordinary 3D printer, so the machine winds the thread itself. It needs the adapter in [`adapter/`](adapter/) on the print head.

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

The thread colour, wood colour, board shape and nail tip belong to the 3D preview and survive regenerating, so you can try different parameters without losing them.

Before solving, the worker rasterises every chord once into a single flat buffer, so the search only has to add up bytes. A run of 3000 lines over 288 pins takes roughly a third of a second. That buffer grows with both the pin count and the working resolution, so extreme combinations (around 1000 pins at 1200 px) are refused up front with a message rather than exhausting the tab's memory.

Results can be exported as the raw pin sequence (`.txt`), a preview `.png`, or a multi-page **instructions PDF** listing every step as `from » to`. The estimated thread length uses the radius set on the template tab, so both tabs describe the same physical piece.

## 3D preview

Once a sequence exists, a **3D preview** shows what the finished piece would look like on a board. Drag to turn it, scroll to move closer. The nails are always black, but you can pick the thread colour and the wood colour, switch the support between a rectangular and a round board, and choose the **nail tip**. Either way the board is slightly wider than the drawing, so the nail circle always sits inside it.

**Nail tip** offers the same three ends as the STL tab — a straight post, a shrimp curl, or a tip tapered 30% wider — built to the same proportions, so the preview shows the nails you are about to print rather than a stand-in. Each one is a tube through a few circular sections, like the printed nail, and every curl bends radially outwards, away from the middle of the board.

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

Instead of drilling a board you can print the circle. This tab builds either a
flat **ring** (a band with a nail on every point), a solid **square board**, or a
solid **circular board**, and exports it as a **binary STL in millimetres**,
which any slicer opens at the right size.

It reads the same **number of points** and **circle radius** as the template tab,
so the printed part and the printed template describe the same circle. Choose a
ring alone, or a square / circular board with that same nail ring raised on top
as relief. The band straddles the point circle, so the thread still runs at
exactly the requested radius.

**Numbered arrow ring** adds a slim second ring around that nail circle with one
inward pointer per nail — the same path for ring, square, or round bases. It
comes as its own STL in the download (a ZIP whenever more than one file is
needed), so you can fit it for numbering and take it off again.

| Input | Default | Meaning |
| --- | --- | --- |
| Nail height | 12 mm | How far a nail stands above the band |
| Nail diameter | 3 mm | Measured across the corners of the printed prism |
| Nail tip | straight | Straight, a shrimp curl, or tapered 30% wider |
| Ring width | 10 mm | Radial width of the band |
| Ring thickness | 4 mm | Height of the band itself |
| Ring segments | 1 | How many arcs to cut the ring into |
| Joint clearance | 0.25 mm | Play left between a tab and its slot |
| Numbered arrow ring | off | Separate outer ring with one numbered pointer per nail |

### How the nails end

Thread wraps the outer face of a nail and is pulled towards the centre of the circle, so the one way a finished loop can escape is upwards, over the tip. **Nail tip** offers three ends, and the second and third both work by making the top harder to leave than the shaft:

- **Straight** is a plain post, quickest to print and the lightest of the three. Use it when the nails are tall enough that the thread never reaches the top anyway.
- **Shrimp curl** climbs about two thirds of the height and then turns 100° outwards, ending in a tip that hangs over the shaft — roughly 5 mm past the nail axis at the default size — with the thread caught in the crook. The turn tapers to 72% of the shaft, which is what gives it the shrimp outline. It reaches its full height at the crown of the bend rather than at the tip, so a curl stands exactly as tall as the straight nail it replaces, and it takes no extra room between neighbours because it bends radially rather than along the ring. It does overhang, so print it with supports.
- **Tapered 30% wider** grows steadily from the base to a tip 30% thicker, a cone the loop cannot ride up. It prints without supports, since the flare is only a few tenths of a millimetre off vertical, but the wide end is what the neighbouring nails have to make room for: the reported gap between nails is measured there, and on a crowded ring the tips will merge before the bases would.

The gap between nails, and the warning that goes with it, always refer to the widest end of whichever tip is chosen, and the summary adds the tip diameter for a cone or the overhang for a curl. All three shapes work on a ring that is cut into arcs and on a mould that carries a numbered arrow ring.

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

## Printer G-code

The last tab hands the picture to a 3D printer. The printed nail ring goes on the
bed, a thread guide hangs off the print head on the adapter in
[`adapter/`](adapter/), and the printer becomes an XY plotter that walks the
thread round the nails. No heater and no extruder is touched anywhere in the file.

It takes the sequence straight from the generator tab, or a `.txt` saved earlier,
and reads the same **number of points** and **circle radius** as the other tabs.
The parts and the fitting are described in [`adapter/README.md`](adapter/README.md);
the tab itself needs three more numbers, measured once: how far the guide sits
from the nozzle in X and Y, and how far below it.

| Input | Default | Meaning |
| --- | --- | --- |
| Ring thickness | 4 mm | Base thickness the mould was printed at |
| Wrap height | 6 mm | Where the thread is laid on the nail, above the ring |
| Guide offset X / Y | 37.2, −42 mm | Where the guide is, from the nozzle |
| Guide below the nozzle | 30 mm | How far it hangs down; the nails have to pass under the head |
| Guide tip radius | 2 mm | Half the width of the 4 mm PTFE stub the thread runs down |
| Travel / wrapping speed | 3000 / 900 mm/min | At the guide |
| Acceleration | 800 mm/s² | Low on purpose: the bed carries the ring |
| Straight moves per turn | 12 | How finely each lap round a nail is chopped up |

### What the job looks like

Each wrap is a straight run to the next nail and then a lap round it. The lap
comes in on the side the thread arrives from, goes all the way round — a whole
turn is what leaves a loop on the nail — and carries on to the side the thread is
going to, so the exit costs nothing. The radius of that lap is the same
compromise the winding machine used: far enough out that the guide is not
grinding along the nail, close enough in that it does not catch the next one
along. Everything is written as `G1` moves rather than `G2`/`G3`, because not
every printer's firmware has arcs turned on.

Because the guide is offset from the nozzle, every move is worked out for the
guide and then written down for the nozzle, and what limits the picture is not
the bed but the overlap between the bed and where the guide can be put — about
180 mm across on a 220 mm bed. The drawing on the tab shows that window, the
ring, and the wider circle the guide swings through, which is the quickest way to
see whether a ring will fit and where to tape it down.

The summary reports the point spacing, the orbit radius, **how many nails that
radius has room for**, the nozzle height while winding, the distance travelled,
an estimate of the time, and the size of the file. Warnings appear when the nails
are too close for the guide to pass between them, and when the job needs more
room than the guide can reach.

## Project layout

```
index.html   the entire application
adapter/     OpenSCAD sources and STLs for the print head adapter
README.md    this file
LICENSE
```
