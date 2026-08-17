#!/usr/bin/env bash
#
# Export the machine one piece at a time, each mesh already sitting where it
# belongs, plus a manifest saying what the pieces are and what order they go on
# in. That is everything ../index.html needs to build the machine up in front of
# you as you tick the parts off.
#
#   ./export-assembly.sh              every piece
#   ./export-assembly.sh frame        just the ones whose name contains "frame"
#   ./export-assembly.sh --manifest   only the manifest, for when the prose moved
#   FN=32 ./export-assembly.sh        smoother, larger, slower
#
# The list comes out of assembly.scad, so nothing here has to be kept in step
# with the machine by hand. These meshes are for looking at, not for printing —
# they are placed rather than laid flat, written binary, and drawn with fewer
# facets than a slicer would want. export.sh is the one that writes parts to
# print.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

openscad="${OPENSCAD:-openscad}"
outdir="stl/assembly"
filter="${1:-}"
meshes=1
if [ "$filter" = "--manifest" ]; then filter=""; meshes=0; fi
# Facets. A tutorial is looked at from far enough away that sixteen is plenty,
# and it is a third of the size and half the wait of the print default.
fn="${FN:-16}"
arc="${ARC_FN:-120}"
jobs="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

mkdir -p "$outdir"

# The manifest arrives as echoes, which openscad only prints on its way to
# producing something; a throwaway .csg is the cheapest something.
scratch=$(mktemp -t assembly-manifest-XXXXXX.csg)
trap 'rm -f "$scratch"' EXIT

manifest=$("$openscad" -D 'piece="manifest"' -o "$scratch" assembly.scad 2>&1 |
           sed -n 's/^ECHO: "\(STEP\|PIECE\) \(.*\)"$/\1 \2/p')

if [ -z "$manifest" ]; then
    echo "could not read the piece list out of assembly.scad" >&2
    exit 1
fi

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# What to actually do at each step is written out in README.md, so it is read
# from there rather than said twice. The numbered list under "Assembly order",
# one paragraph per step, minus its bold heading, which is the step's name and
# the manifest has it already.
notes=$(awk '
    /^## Assembly order/ { on = 1; next }
    on && /^## / { exit }
    on && /^[0-9]+\. / {
        if (n) print "NOTE " n " " text
        n = $1; sub(/\./, "", n)
        text = substr($0, index($0, " ") + 1)
        sub(/^\*\*[^*]*\*\* */, "", text)
        next
    }
    on && /^ +[^ ]/ { text = text " " $0; next }
    on && n && /^$/ { print "NOTE " n " " text; n = "" }
    END { if (n) print "NOTE " n " " text }
' README.md | sed 's/[`*]//g; s/  */ /g')

# ------------------------------------------------------------------ the meshes
# One openscad per piece, run a few at a time. Warnings are fatal: if one
# appears the model is wrong, not the script.
render() {  # render <piece> <index> <file>
    if ! log=$("$OPENSCAD_BIN" --hardwarnings --export-format binstl \
                               -D "\$fn=$FN_ARG" -D "arc_fn=$ARC_ARG" \
                               -D "piece=\"$1\"" -D "index=$2" \
                               -o "$OUTDIR/$3.stl" assembly.scad 2>&1) ||
       printf '%s' "$log" | grep -qiE 'warning|error'; then
        printf '%-28s FAILED\n' "$3"
        printf '%s\n' "$log" >&2
        exit 1
    fi
    printf '%-28s %8s\n' "$3" "$(stat -c %s "$OUTDIR/$3.stl")"
}
export -f render
export OPENSCAD_BIN="$openscad" FN_ARG="$fn" ARC_ARG="$arc" OUTDIR="$outdir"

work=$(mktemp)
trap 'rm -f "$scratch" "$work"' EXIT

while read -r kind rest; do
    [ "$kind" = "PIECE" ] || continue
    read -r name count step bought colour label <<< "$rest"
    [ "$count" -gt 0 ] || continue
    case "$name" in *"$filter"*) ;; *) continue ;; esac
    for i in $(seq 0 $((count - 1))); do
        printf '%s %s %s_%s\n' "$name" "$i" "$name" "$i" >> "$work"
    done
done <<< "$manifest"

total=$(wc -l < "$work")
if [ "$meshes" = 1 ]; then
    echo "$total meshes, ${jobs} at a time, \$fn=$fn"
    xargs -a "$work" -r -P "$jobs" -L1 bash -c 'render "$@"' _
else
    echo "leaving the $total meshes alone"
fi

# ---------------------------------------------------------------- the manifest
# Written last, so a manifest on disk always means the meshes beside it are
# whole. Only what got rendered goes in it.
out="$outdir/manifest.json"
{
    printf '{\n  "steps": [\n'
    first=1
    while read -r kind rest; do
        [ "$kind" = "STEP" ] || continue
        read -r n name <<< "$rest"
        note=$(printf '%s\n' "$notes" | sed -n "s/^NOTE $n //p")
        [ $first = 1 ] || printf ',\n'
        printf '    { "n": %s, "name": "%s", "note": "%s" }' \
               "$n" "$(json_escape "$name")" "$(json_escape "$note")"
        first=0
    done <<< "$manifest"

    printf '\n  ],\n  "pieces": [\n'
    first=1
    while read -r kind rest; do
        [ "$kind" = "PIECE" ] || continue
        read -r name count step bought colour label <<< "$rest"
        [ "$count" -gt 0 ] || continue
        case "$name" in *"$filter"*) ;; *) continue ;; esac
        for i in $(seq 0 $((count - 1))); do
            [ $first = 1 ] || printf ',\n'
            printf '    { "id": "%s_%s", "part": "%s", "label": "%s", "n": %s, "of": %s, "step": %s, "bought": %s, "colour": "%s" }' \
                   "$name" "$i" "$name" "$(json_escape "$label")" \
                   "$((i + 1))" "$count" "$step" \
                   "$([ "$bought" = 1 ] && echo true || echo false)" \
                   "$(json_escape "$colour")"
            first=0
        done
    done <<< "$manifest"
    printf '\n  ]\n}\n'
} > "$out"

echo
echo "$total pieces and a manifest in $here/$outdir"
echo "serve the machine folder and open index.html to walk through them"
