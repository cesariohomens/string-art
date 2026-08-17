#!/usr/bin/env bash
#
# A video of the machine winding a picture: every part in place, the board
# turning under the guide, and the thread appearing behind it.
#
#   ./animate.sh                        the stock ring, a film in three shots
#   ./animate.sh --shot close           one camera, the whole job
#   ./animate.sh --seq mine.txt         a sequence saved from the app
#   ./animate.sh --gcode job.gcode      a job already written, from the app or elsewhere
#   ./animate.sh --out anim/mine.mp4    somewhere other than anim/machine.mp4
#   ./animate.sh --nails 96 --radius 200 --passes 1 --seconds 12
#
# The job:       --nails N  --radius MM  --seq FILE
#                --passes N  --step N  --wraps N     for the made-up sequence
#                --gcode FILE                       a finished job instead of any of that
# The film:      --seconds N  --fps N  --shot all|wide|close|high
#                --close-speed N        machine seconds per video second, near shot
# The file:      --size WxH  --super N  --out FILE  --keep  --jobs N
#
# The path is not made up here. The job goes through walk.cpp, which is the
# firmware's own g-code reader and geometry compiled for a PC, so the guide in
# the video goes where the machine would go, wraps what the machine would wrap
# and takes as long as the machine would take, bar acceleration. Everything the
# frames need beyond that — the ring, the thread, where the axes are — is fed to
# machine.scad, which is the same model the parts are printed from.
#
# Rendering is the preview renderer, one process per core, at twice the output
# size and scaled down, because OpenSCAD does not anti-alias and a 0.9 mm thread
# on a 740 mm machine is one pixel wide. Thirty seconds takes about a quarter of
# an hour on twelve cores; --size 640x360 --super 1 --fps 15 takes half a minute.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

openscad="${OPENSCAD:-openscad}"
ffmpeg="${FFMPEG:-ffmpeg}"
firmware="$here/../firmware"

nails=288           # nails on the ring
radius=280          # the circle they stand on, mm
passes=2            # how many envelopes the made-up sequence draws
wraps=0             # cut the sequence short, 0 for all of it
step=0              # nails to skip per leg, 0 to choose one
seq_file=""         # a sequence saved from the app instead
gcode_file=""       # a finished job instead of building one
seconds=30          # how long the video runs
close_speed=1.5     # machine seconds per video second in the near shot
fps=30
width=1920
height=1080
super=2             # render this many times bigger, then scale down
shot=all            # all, wide, close or high
out="anim/machine.mp4"
jobs="$(nproc)"
keep=0

while [ $# -gt 0 ]; do
    case "$1" in
        --nails)   nails="$2"; shift 2 ;;
        --radius)  radius="$2"; shift 2 ;;
        --passes)  passes="$2"; shift 2 ;;
        --wraps)   wraps="$2"; shift 2 ;;
        --step)    step="$2"; shift 2 ;;
        --seq)     seq_file="$2"; shift 2 ;;
        --gcode)   gcode_file="$2"; shift 2 ;;
        --seconds) seconds="$2"; shift 2 ;;
        --close-speed) close_speed="$2"; shift 2 ;;
        --fps)     fps="$2"; shift 2 ;;
        --size)    width="${2%%x*}"; height="${2##*x}"; shift 2 ;;
        --super)   super="$2"; shift 2 ;;
        --shot)    shot="$2"; shift 2 ;;
        --out)     out="$2"; shift 2 ;;
        --jobs)    jobs="$2"; shift 2 ;;
        --keep)    keep=1; shift ;;
        -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "$0: no such option: $1" >&2; exit 1 ;;
    esac
done

if [ -n "$gcode_file" ] && [ -n "$seq_file" ]; then
    echo "$0: --gcode and --seq are different jobs; pick one" >&2
    exit 1
fi
if [ -n "$gcode_file" ] && [ ! -f "$gcode_file" ]; then
    echo "$0: no such g-code file: $gcode_file" >&2
    exit 1
fi

case "$shot" in all|wide|close|high) ;; *) echo "$0: no such shot: $shot" >&2; exit 1 ;; esac

# h264 will not take an odd side, and a video one row short of what was asked
# for is better than no video at all.
width=$((width - width % 2))
height=$((height - height % 2))

work="anim"
frames="$work/frames"
rm -rf "$frames"
mkdir -p "$frames" "$(dirname "$out")"

# ---------------------------------------------------------------------------
# The dimensions the cameras are aimed with come out of the model, so moving
# the machine moves the shots with it.
# ---------------------------------------------------------------------------
# The probe has to sit beside config.scad: an include is resolved against the
# file that asks for it, not against the working directory.
probe=".probe.scad"
trap 'rm -f "$here/$probe" "$here/$probe.csg"' EXIT
cat > "$probe" <<'EOF'
include <config.scad>
echo(str("N z_zero ", z_zero));
echo(str("N x_max ", x_max));
EOF
eval "$("$openscad" -o "$probe.csg" "$probe" 2>&1 |
        sed -n 's/^ECHO: "N \([a-z_]*\) \(.*\)"$/\1=\2/p')"
rm -f "$probe" "$probe.csg"

for n in z_zero x_max; do
    case "${!n:-}" in
        ''|*[!0-9.]*) echo "$0: config.scad would not say what $n is" >&2; exit 1 ;;
    esac
done

# The orbit the app would pick, and whether this ring fits this machine at all.
# A finished job already carries its own orbit in M701, so this only runs when
# the script is the one writing the job.
if [ -z "$gcode_file" ]; then
    orbit=$(awk -v r="$radius" -v n="$nails" -v reach="$x_max" 'BEGIN {
        low = 3 / 2 + 1.1
        high = 2 * 3.14159265 * r / n - 3 / 2 - 1.1
        if (high < low) { print "crowded"; exit }
        want = low + 0.4
        o = (want > high) ? (low + high) / 2 : want
        if (r + o + 1.1 > reach) { print "far"; exit }
        printf "%.2f\n", o
    }')
    case "$orbit" in
        crowded) echo "$0: $nails nails on a $radius mm circle leaves the guide no room" >&2; exit 1 ;;
        far)     echo "$0: a $radius mm ring is past a machine that reaches $x_max mm" >&2; exit 1 ;;
    esac
fi

# ---------------------------------------------------------------------------
# The job: either one already written, or a sequence then the lines the app
# would send for it.
# ---------------------------------------------------------------------------
job="$work/job.gcode"
if [ -n "$gcode_file" ]; then
    # Resolve it now: the work directory is not where the user was standing.
    case "$gcode_file" in
        /*) job="$gcode_file" ;;
        *)  job="$(cd "$(dirname "$gcode_file")" && pwd)/$(basename "$gcode_file")" ;;
    esac
else
    if [ -n "$seq_file" ]; then
        order=$(tr -cs '0-9' '\n' < "$seq_file" | sed '/^$/d')
        if [ -z "$order" ]; then echo "$0: no nail numbers in $seq_file" >&2; exit 1; fi
        # A saved sequence carries no nail count of its own, so it comes from the
        # highest number in it, exactly as the app does it.
        biggest=$(printf '%s\n' "$order" | sort -n | tail -1)
        if [ "$biggest" -ge "$nails" ]; then nails=$((biggest + 1)); fi
    else
        # A leg that skips a fixed number of nails draws the envelope of a circle,
        # which is the plainest thing that looks like string art. Skipping a count
        # that shares no factor with the ring visits every nail and closes up, so
        # each pass is one whole envelope, and successive passes step in.
        order=$(awk -v n="$nails" -v passes="$passes" -v fixed="$step" '
            function gcd(a, b) { while (b) { t = a % b; a = b; b = t } return a }
            BEGIN {
                split("0.381966 0.236068 0.145898 0.090170", ratio, " ")
                if (passes > 4) passes = 4
                if (passes < 1) passes = 1
                at = 0
                for (p = 1; p <= passes; p++) {
                    s = fixed > 0 ? fixed : int(n * ratio[p])
                    if (s < 1) s = 1
                    while (gcd(n, s) != 1 && s < n) s++
                    if (s >= n) s = 1
                    for (i = 0; i < n; i++) { at = (at + s) % n; print at }
                }
            }')
    fi

    if [ "$wraps" -gt 0 ]; then order=$(printf '%s\n' "$order" | head -n "$wraps"); fi
    count=$(printf '%s\n' "$order" | wc -l)

    {
        echo "; string art winding job"
        printf '; %s nails on a %.1f mm circle, %s wraps\n' "$nails" "$radius" "$count"
        echo "M115"
        echo "G28"
        printf 'M701 R%.2f N%s H6.00 D3.00 O%s P0.00\n' "$radius" "$nails" "$orbit"
        echo "M702 F4200 S1200"
        echo "G92 A0"
        echo "M17"
        echo "G0 Z6.00"
        printf 'M700 P%s\n' $order
        echo "M400"
        echo "G0 Z20.00"
        echo "M18"
    } > "$job"
fi

# ---------------------------------------------------------------------------
# The path, sampled one row per frame.
# ---------------------------------------------------------------------------
walk="$work/walk"
sources=("$firmware/tools/walk.cpp" "$firmware/src/geometry.cpp" "$firmware/src/gcode.cpp")
stale=0
for src in "${sources[@]}"; do [ "$src" -nt "$walk" ] && stale=1; done
if [ ! -x "$walk" ] || [ "$stale" = 1 ]; then
    g++ -O2 -I "$firmware/src" "${sources[@]}" -o "$walk"
fi

header=$("$walk" < "$job")
read -r job_secs job_wraps job_first <<< "$(sed -n 's/^# job //p' <<< "$header")"
seq_list="[$(sed -n 's/^# seq //p' <<< "$header" | tr ' ' ',')]"

# A finished job says what ring it is for; that is what the model has to draw,
# not whatever --nails / --radius were left at.
if [ -n "$gcode_file" ]; then
    read -r radius nails _ <<< "$(sed -n 's/^# ring //p' <<< "$header")"
    if [ -z "$radius" ] || [ -z "$nails" ]; then
        echo "$0: $gcode_file never says what ring it is for" >&2
        exit 1
    fi
fi
# A shot is a name, how far through it the frame is, and where the machine is.
# Sections of the film get their own window of machine time, which is what lets
# the near shot run slowly enough to see a nail being wrapped while the wide one
# gets through the rest of the job.
plan="$work/plan.txt"
: > "$plan"

walked() {  # walked <shot> <from> <to> <frames>
    "$walk" --from "$2" --to "$3" --frames "$4" < "$job" | grep -v '^#' |
        awk -v shot="$1" -v n="$4" \
            '{ printf "%s %.6f %s %s %s %s\n", shot, (n > 1 ? (NR - 1) / (n - 1) : 0), $1, $2, $3, $4 }'
}

held() {  # held <shot> <frames>: the finished picture, with nothing moving
    "$walk" --from "$job_secs" --to "$job_secs" --frames 1 < "$job" |
        grep -v '^#' |
        awk -v shot="$1" -v n="$2" \
            '{ for (i = 0; i < n; i++) printf "%s %.6f %s %s %s %s\n", shot, (n > 1 ? i / (n - 1) : 0), $1, $2, $3, $4 }'
}

frames_for() { awk -v s="$1" -v f="$fps" 'BEGIN { printf "%d", (s * f) + 0.5 }'; }

if [ "$shot" = all ]; then
    # Near, wide, then the picture: in that order it is one run of the machine
    # from the first nail to the last, with no jumping about in time.
    # The near shot opens a couple of seconds before the first nail is wrapped,
    # so it holds a lap rather than the run out to it or the long crossing after.
    near_start=$(awk -v t0="$job_first" 'BEGIN { t = t0 - 2; print (t < 0) ? 0 : t }')
    near_end=$(awk -v s="$seconds" -v k="$close_speed" -v job="$job_secs" -v t0="$near_start" \
        'BEGIN { t = t0 + s * 0.2 * k; print (t > job) ? job : t }')
    walked close "$near_start" "$near_end" "$(frames_for "$(awk -v s="$seconds" 'BEGIN { print s * 0.2 }')")" >> "$plan"
    walked wide "$near_end" "$job_secs" "$(frames_for "$(awk -v s="$seconds" 'BEGIN { print s * 0.6 }')")" >> "$plan"
    held high "$(frames_for "$(awk -v s="$seconds" 'BEGIN { print s * 0.2 }')")" >> "$plan"
else
    walked "$shot" 0 "$job_secs" "$(frames_for "$seconds")" >> "$plan"
fi

job_frames=$(wc -l < "$plan")
if [ "$job_frames" -lt 1 ]; then
    echo "$0: ${seconds}s at $fps fps is not enough for a frame" >&2
    exit 1
fi

printf 'ring     %s nails, %s mm radius, %s wraps\n' "$nails" "$radius" "$job_wraps"
printf 'job      %s of machine time in %ss of video, %s frames at %s fps\n' \
    "$(awk -v s="$job_secs" 'BEGIN { printf "%dh %02dm %02ds", s / 3600, (s % 3600) / 60, s % 60 }')" \
    "$seconds" "$job_frames" "$fps"

# ---------------------------------------------------------------------------
# Where the camera is, frame by frame: a shot is an eye and a point it looks at.
# The two wide ones swing round the machine; the near one stands still, because
# the guide only ever meets the ring in one place.
# ---------------------------------------------------------------------------
args="$work/args.txt"
awk -v z0="$z_zero" -v ring="$radius" -v seq="$seq_list" -v dir="$frames" '
function eye(d, elev, az, cz,   ce) {
    ce = d * cos(elev * PI / 180)
    return sprintf("%.2f,%.2f,%.2f", ce * cos(az * PI / 180),
                   ce * sin(az * PI / 180), cz + d * sin(elev * PI / 180))
}
function span(u, a, b) { return a + (b - a) * u }
BEGIN { PI = 3.14159265358979 }
{
    name = $1; v = $2; a = $3; x = $4; z = $5; laid = $6

    if (name == "wide") {
        # Round the machine at a working height, closing in as it goes. The
        # carriage sits on the +X rail, so the sweep stays away from there or it
        # ends up looking at the back of it.
        cz = z0 + 15
        cam = eye(span(v, 1230, 1170), span(v, 24, 31), span(v, -74, -34), cz) ",0,0," cz
    } else if (name == "high") {
        # Over the finished picture, coming down and round to face it.
        cz = z0 + 5
        cam = eye(span(v, 1420, 1220), span(v, 60, 47), span(v, -86, -48), cz) ",0,0," cz
    } else {
        # Held on the one place every lap happens — the guide only ever meets
        # the ring where the rail crosses it — and pushed in until a lap round a
        # nail is a lap and not a twitch. Following the guide instead would
        # spend most of the shot over the empty middle of the board, which is
        # where it spends most of its time.
        cam = sprintf("%.2f,%.2f,%.2f,%.2f,%.2f,%.2f",
                      ring + span(v, 210, 34), span(v, 285, 56), z0 + span(v, 135, 27),
                      ring, 0, z0 + 8)
    }

    printf "--projection=p --camera=%s -D a_pos=%.4f -D x_pos=%.4f -D z_pos=%.4f", cam, a, x, z
    printf " -D laid=%d -D seq=%s -D ring_r=%.2f -o %s/%05d.png\n", laid, seq, ring, dir, NR
}' "$plan" > "$args"

# ---------------------------------------------------------------------------
# Render, one process per core.
# ---------------------------------------------------------------------------
echo "drawing $(wc -l < "$args") frames on $jobs cores"
start=$SECONDS
xargs -a "$args" -P "$jobs" -L 1 -r \
    "$openscad" -q --colorscheme=Tomorrow \
    --imgsize=$((width * super)),$((height * super)) machine.scad
echo "drawn in $((SECONDS - start))s"

drawn=$(find "$frames" -name '*.png' | wc -l)
if [ "$drawn" -lt "$job_frames" ]; then
    echo "$0: only $drawn of $job_frames frames came out" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Encode. The last frame is held for a moment: the finished picture is the
# point of the whole thing.
# ---------------------------------------------------------------------------
"$ffmpeg" -y -loglevel error -framerate "$fps" -i "$frames/%05d.png" \
    -vf "scale=$width:$height:flags=lanczos,tpad=stop_mode=clone:stop_duration=2" \
    -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -movflags +faststart "$out"

[ "$keep" = 1 ] || rm -rf "$frames"

echo
echo "video is $here/$out ($(du -h "$out" | cut -f1))"
