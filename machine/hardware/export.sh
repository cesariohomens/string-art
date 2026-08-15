#!/usr/bin/env bash
#
# Export every printed part to machine/hardware/stl/, one STL per part, turned
# the way it should be printed.
#
#   ./export.sh                 every part
#   ./export.sh x_carriage      just the ones whose name contains "x_carriage"
#
# The list of parts, how many of each are needed and which of them are cut
# differently depending on where they sit comes from parts.scad, so nothing
# here has to be kept in step with the model by hand. Parts that differ get one
# file each, numbered from zero: frame_sector_0.stl and so on.
#
# A full run renders every part with CGAL and takes a couple of minutes on a
# quiet machine. Warnings are fatal; if one appears, the model is wrong, not
# the script.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

openscad="${OPENSCAD:-openscad}"
outdir="stl"
filter="${1:-}"

mkdir -p "$outdir"

# The manifest comes out as echoes, which openscad will only print while it is
# on its way to producing something; a throwaway .csg is the cheapest something.
scratch=$(mktemp -t parts-manifest-XXXXXX.csg)
trap 'rm -f "$scratch"' EXIT

manifest=$("$openscad" -D 'part="manifest"' -o "$scratch" parts.scad 2>&1 |
           sed -n 's/^ECHO: "PART \(.*\)"$/\1/p')

if [ -z "$manifest" ]; then
    echo "could not read the part list out of parts.scad" >&2
    exit 1
fi

export_one() {  # export_one <part> <index> <basename>
    local log
    printf '%-32s' "$3"
    if ! log=$("$openscad" --hardwarnings -D "part=\"$1\"" -D "index=$2" \
                           -o "$outdir/$3.stl" parts.scad 2>&1) ||
       printf '%s' "$log" | grep -qiE 'warning|error'; then
        echo "FAILED"
        printf '%s\n' "$log" >&2
        exit 1
    fi
    echo "ok"
}

while read -r name qty indexed; do
    [ "$qty" -gt 0 ] || continue
    case "$name" in
        *"$filter"*) ;;
        *) continue ;;
    esac
    if [ "$indexed" = "1" ]; then
        for i in $(seq 0 $((qty - 1))); do
            export_one "$name" "$i" "${name}_${i}"
        done
    else
        export_one "$name" 0 "$name"
    fi
done <<< "$manifest"

echo
echo "STLs are in $here/$outdir"
