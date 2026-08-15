include <config.scad>
use <assembly.scad>

// The whole machine, printed parts and bought ones, at whatever position of
// the three axes you care to set below. It is here to be looked at: to check
// that the guide reaches the nail circle, that nothing the carriage carries
// passes over the board, and that the parts that bolt to each other agree
// about where the holes are.
//
// Where each piece sits is assembly.scad's business, not this file's. What is
// left here is the job on the board — the thread, and the board it is laid on —
// which is the part that moves while a job runs.
//
// The axis values are the ones the protocol uses. A is degrees of turntable, X
// is the distance from the turntable axis to the eyelet, and Z is the height
// of the eyelet above the surface of the board.

a_pos = 0;
x_pos = x_max;
z_pos = 0;

// The job on the board, which is what animate.sh drives frame by frame. On its
// own the model draws the biggest ring the machine takes and no thread at all,
// which is the arrangement worth checking the reach against.
ring_r = board_radius_max;
ring_nails = nail_count;
ring_phase = 0;
wrap_z = 6;             // where the thread is laid on the shank
seq = [];               // the nails the job goes round, in the order it does
laid = 0;               // how many of them are behind it

machine();

module machine() {
    assembly(a_pos, x_pos, z_pos, board = false);
    // The board is keyed to the spigot, so it turns with the table and so does
    // everything drawn on it. It is drawn here rather than left to the assembly
    // because a job puts its own ring on it.
    if (show_board) rotate([0, 0, a_pos]) {
        board(ring_r, ring_nails, ring_phase);
        thread();
    }
    if (len(seq) > 0) feed_line();
}

// The thread: every leg the job has already laid, and the one being laid now,
// running from the last nail the job went round to wherever the eyelet has got
// to. Before the first lap that last nail is the one the thread was tied to by
// hand, which is where the job starts. The eyelet is fixed on the +X rail, so in
// the turning board's own frame it comes round the other way.
module thread() {
    if (len(seq) > 0) color("#26262c") {
        for (i = [1 : max(1, laid) - 1])
            strand(nail(seq[i - 1]), nail(seq[i]));
        strand(nail(seq[max(0, laid - 1)]),
               [x_pos * cos(-a_pos), x_pos * sin(-a_pos), z_zero + z_pos]);
    }
}

// Where the thread sits on nail i of the job's own ring.
function nail(i) = nail_at(i, ring_r, ring_nails, ring_phase, wrap_z);

// The working thread on its way in: off the spool, past the arm that keeps it
// under tension, and down the top of the guide tube, which is wherever the
// carriage has taken it.
module feed_line() {
    from = [-gantry_x, rail_y - upright_t / 2 - 22, frame_top_z + upright_h / 2 + 10];
    to = [x_pos, 0, z_pos + guide_clamp_z1];
    color("#26262c") strand(from, to);
}

module strand(p, q) {
    d = q - p;
    len = norm(d);
    if (len > 0.05)
        translate((p + q) / 2)
            rotate([0, 0, atan2(d[1], d[0])])
                rotate([0, -asin((q[2] - p[2]) / len), 0])
                    cube([len, thread_w, thread_w], center = true);
}
