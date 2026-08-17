#!/usr/bin/env bash
#
# Export every printed part to adapter/stl/, one STL per part, turned the way it
# should be printed.
#
#   ./export.sh            every part
#   ./export.sh collar     just the ones whose name contains "collar"
#
# The list comes out of parts.scad, so nothing here has to be kept in step with
# the model by hand. Warnings are fatal: if one appears the model is wrong, not
# the script.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

openscad="${OPENSCAD:-openscad}"
outdir="stl"
filter="${1:-}"

mkdir -p "$outdir"

# The manifest comes out as echoes, which openscad will only print while it is on
# its way to producing something; a throwaway .csg is the cheapest something.
scratch=$(mktemp -t parts-manifest-XXXXXX.csg)
trap 'rm -f "$scratch"' EXIT

manifest=$("$openscad" -D 'part="manifest"' -o "$scratch" parts.scad 2>&1 |
           sed -n 's/^ECHO: "PART \(.*\)"$/\1/p')

if [ -z "$manifest" ]; then
    echo "could not read the part list out of parts.scad" >&2
    exit 1
fi

while read -r name qty; do
    [ "$qty" -gt 0 ] || continue
    case "$name" in
        *"$filter"*) ;;
        *) continue ;;
    esac
    printf '%-32s' "$name"
    if ! log=$("$openscad" --hardwarnings -D "part=\"$name\"" \
                           -o "$outdir/$name.stl" parts.scad 2>&1) ||
       printf '%s' "$log" | grep -qiE 'warning|error'; then
        echo "FAILED"
        printf '%s\n' "$log" >&2
        exit 1
    fi
    echo "ok"
done <<< "$manifest"

echo
echo "STLs are in $here/$outdir"
