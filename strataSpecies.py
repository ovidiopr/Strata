"""What comes out of a target, by species, from Strata's track files.

Pairs with macros/tandem_stripper.mac, but nothing here is specific to it:
any run with /strata/files/savePrimaries or saveCascades can be read.

Each line of a track file is one end of one step:

    ev  stp  id  parent  name  time  x y z  px py pz  Ek  proc

so a track is every line sharing an event and a track id, and the last of
them is where that track ended.  This groups them, reports what species
are present and with what energy, and optionally restricts the count to
tracks that got past a plane, the exit face of a stripper cell, say.

A warning about charge states, since that is usually the next question.
Geant4 does not track one: an ion's charge state is not a dynamic
quantity, the charge given to /gun/ion is not what the equation of motion
uses, and no process in the standard physics lists strips or captures
electrons.  Nothing in a track file carries it.  What this script can do
is give the exit energy per nucleon and the reduced velocity, which is
what an external charge-state parameterisation takes as input.

Usage:
    python strataSpecies.py stripper_primaries.txt stripper_recoils.txt
    python strataSpecies.py stripper_recoils.txt --past 50
    python strataSpecies.py *.txt --csv species.csv --plot
"""

import math
import os
import re
import sys

# Z by symbol, enough for anything a track file is likely to name
_SYMBOLS = (
    "H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca Sc Ti V Cr Mn Fe "
    "Co Ni Cu Zn Ga Ge As Se Br Kr Rb Sr Y Zr Nb Mo Tc Ru Rh Pd Ag Cd In "
    "Sn Sb Te I Xe Cs Ba La Ce Pr Nd Pm Sm Eu Gd Tb Dy Ho Er Tm Yb Lu Hf "
    "Ta W Re Os Ir Pt Au Hg Tl Pb Bi Po At Rn Fr Ra Ac Th Pa U"
).split()
_Z_OF = {s: i + 1 for i, s in enumerate(_SYMBOLS)}

# Geant4 writes ions as symbol + mass number, with an excitation suffix for
# an isomer; everything else is a name of its own
_ION = re.compile(r"^([A-Z][a-z]?)(\d+)(\[[\d.]+\])?$")

_NAMED = {                       # name: (Z, A)
    "proton": (1, 1), "anti_proton": (-1, 1), "neutron": (0, 1),
    "deuteron": (1, 2), "triton": (1, 3), "alpha": (2, 4), "He3": (2, 3),
    "e-": (-1, 0), "e+": (1, 0), "gamma": (0, 0),
    "mu-": (-1, 0), "mu+": (1, 0),
}

AMU_MEV = 931.49410242        # one atomic mass unit, MeV/c^2
ALPHA_INV = 137.035999084     # c / v0, the inverse fine structure constant


def ion_of(name):
    """(Z, A) for a particle name, or (None, None) when it is not an ion."""
    if name in _NAMED:
        return _NAMED[name]
    m = _ION.match(name)
    if m and m.group(1) in _Z_OF:
        return _Z_OF[m.group(1)], int(m.group(2))
    return None, None


class Track:
    """The end of one track: where it stopped and what it was."""

    __slots__ = ("event", "tid", "parent", "name", "x", "y", "z",
                 "px", "py", "pz", "energy", "process", "max_x", "steps")

    def __init__(self, event, tid, parent, name):
        self.event, self.tid, self.parent, self.name = event, tid, parent, name
        self.max_x = -math.inf
        self.steps = 0

    def update(self, fields):
        self.x, self.y, self.z = (float(v) for v in fields[6:9])
        self.px, self.py, self.pz = (float(v) for v in fields[9:12])
        self.energy = float(fields[12])
        self.process = fields[13] if len(fields) > 13 else ""
        self.max_x = max(self.max_x, self.x)
        self.steps += 1

    @property
    def angle(self):
        """Angle to the x axis in degrees, or None when it has stopped."""
        n = math.sqrt(self.px**2 + self.py**2 + self.pz**2)
        if n == 0.0:
            return None
        return math.degrees(math.acos(max(-1.0, min(1.0, self.px / n))))


def read_tracks(paths):
    """Every track in these files, keyed by (file, event, track id).

    A primaries file and a cascades file from the same run hold different
    tracks (id 1 and the rest) so reading both gives the whole event.
    """
    tracks = {}
    for path in paths:
        tag = os.path.basename(path)
        with open(path) as handle:
            for lineno, line in enumerate(handle, 1):
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                f = line.split()
                if len(f) < 13:
                    print(f"  {tag}:{lineno}: {len(f)} fields, skipped",
                          file=sys.stderr)
                    continue
                key = (tag, int(f[0]), int(f[2]))
                track = tracks.get(key)
                if track is None:
                    track = Track(int(f[0]), int(f[2]), int(f[3]), f[4])
                    tracks[key] = track
                track.update(f)
    return list(tracks.values())


def summarise(tracks, past=None):
    """Counts and energies by species, for tracks that got past a plane."""
    rows = {}
    for t in tracks:
        if past is not None and t.max_x < past:
            continue
        rows.setdefault(t.name, []).append(t)
    return rows


def quantile(sorted_values, q):
    if not sorted_values:
        return float("nan")
    i = q * (len(sorted_values) - 1)
    lo, hi = int(math.floor(i)), int(math.ceil(i))
    if lo == hi:
        return sorted_values[lo]
    return sorted_values[lo] + (sorted_values[hi] - sorted_values[lo]) * (i - lo)


def report(rows, events, past, show_charge):
    if not rows:
        print("no tracks matched")
        return []

    total = sum(len(v) for v in rows.values())
    where = "anywhere" if past is None else f"past x = {past:g} mm"
    print(f"\n{total} tracks {where}, from {events} events\n")
    head = (f"{'species':<10}{'tracks':>9}{'per event':>11}"
            f"{'median Ek':>12}{'10%':>11}{'90%':>11}{'median angle':>14}")
    print(head)
    print("-" * len(head))

    out = []
    for name in sorted(rows, key=lambda n: -len(rows[n])):
        ts = rows[name]
        energies = sorted(t.energy for t in ts)
        angles = sorted(a for a in (t.angle for t in ts) if a is not None)
        med = quantile(energies, 0.5)
        row = {
            "species": name, "tracks": len(ts),
            "per_event": len(ts) / events if events else float("nan"),
            "median_MeV": med,
            "p10_MeV": quantile(energies, 0.10),
            "p90_MeV": quantile(energies, 0.90),
            "median_angle_deg": quantile(angles, 0.5) if angles else float("nan"),
        }
        out.append(row)
        print(f"{name:<10}{len(ts):>9}{row['per_event']:>11.4g}"
              f"{med:>12.5g}{row['p10_MeV']:>11.5g}{row['p90_MeV']:>11.5g}"
              f"{row['median_angle_deg']:>14.3f}")
    print("\nenergies in MeV, angle to the beam axis in degrees")

    if show_charge:
        charge_note(rows)
    return out


def charge_note(rows):
    """What an external charge-state formula needs, and why it is needed.

    Geant4 carries no charge state, so this prints the two quantities every
    semi-empirical parameterisation is written in terms of rather than
    inventing a number.  The Bohr velocity criterion is given because it is
    the one estimate simple enough to state exactly (q = (v/v0) Z^(1/3),
    for 1 < v/v0 < Z^(2/3)) and it is a rough upper bound, not a result:
    at the velocities a tandem stripper works at it reads high, and a
    measurement-grade number needs Schiwietz and Grande's gas-target fit
    (NIM B 175-177 (2001) 125) or a code such as LISE++ or GLOBAL.
    """
    ions = [(n, ts) for n, ts in rows.items() if ion_of(n)[0] not in (None, 0)
            and ion_of(n)[1]]
    if not ions:
        return
    print("\nFor a charge-state estimate, which Geant4 does not provide:\n")
    head = (f"{'species':<10}{'Z':>4}{'A':>5}{'median Ek':>12}"
            f"{'MeV/u':>10}{'v/v0':>9}{'Bohr q':>9}{'in range':>10}")
    print(head)
    print("-" * len(head))
    for name, ts in sorted(ions, key=lambda kv: -len(kv[1])):
        z, a = ion_of(name)
        if z <= 0 or a <= 0:
            continue
        e = quantile(sorted(t.energy for t in ts), 0.5)
        # A species that stopped has no velocity to speak of, and a charge
        # state at rest is not what anyone is asking about
        if e <= 0.0:
            print(f"{name:<10}{z:>4}{a:>5}{'at rest':>12}"
                  f"{'-':>10}{'-':>9}{'-':>9}{'-':>10}")
            continue
        per_u = e / a
        beta = math.sqrt(max(0.0, 2.0 * e / (a * AMU_MEV)))
        vrel = beta * ALPHA_INV
        q = min(float(z), vrel * z ** (1.0 / 3.0))
        ok = "yes" if 1.0 < vrel < z ** (2.0 / 3.0) else "no"
        print(f"{name:<10}{z:>4}{a:>5}{e:>12.5g}{per_u:>10.4g}"
              f"{vrel:>9.3f}{q:>9.2f}{ok:>10}")
    print("\nBohr's criterion q = (v/v0) Z^(1/3) holds for 1 < v/v0 < Z^(2/3)")
    print("and reads high near a stripper; use it as a bound, not a result.")
    print("For a real distribution feed MeV/u to Schiwietz and Grande,")
    print("NIM B 175-177 (2001) 125, or to LISE++ / GLOBAL.")


def plot(rows, past, path, top=6):
    """Exit energies by species.

    Energies here run from eV-scale recoils to the MeV beam, so the x axis
    is logarithmic and a species that stopped has nothing to show on it --
    those are reported in the table instead, and named in the title.
    """
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import numpy as np

    order = sorted(rows, key=lambda n: -len(rows[n]))[:top]
    live, stopped, at_rest = [], [], 0
    for name in order:
        total = len(rows[name])
        e = np.array([t.energy for t in rows[name] if t.energy > 0.0])
        at_rest += total - e.size
        (live if e.size else stopped).append((name, e, total))
    if not live:
        print("every track ended at rest; nothing to plot", file=sys.stderr)
        return

    lo = min(e.min() for _, e, _ in live)
    hi = max(e.max() for _, e, _ in live)
    bins = np.logspace(math.log10(lo * 0.8), math.log10(hi * 1.25), 60)

    fig, ax = plt.subplots(figsize=(7.0, 4.0))
    colours = plt.rcParams["axes.prop_cycle"].by_key()["color"]
    for i, (name, e, total) in enumerate(live):
        # Say how many of the species are drawn: a log axis cannot show a
        # track that ended at rest, and a count that quietly differs from
        # the table is worse than no count
        tag = f"{name}  {e.size}" + (f" of {total}" if e.size != total else "")
        ax.hist(e, bins=bins, histtype="step", linewidth=1.4,
                color=colours[i % len(colours)], label=tag)
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlabel("kinetic energy where the track ended (MeV)")
    ax.set_ylabel("tracks")
    where = "anywhere in the target" if past is None else f"past x = {past:g} mm"
    title = f"Species and their energies, {where}"
    notes = []
    if at_rest:
        notes.append(f"{at_rest} tracks ended at rest, off a log axis")
    if stopped:
        notes.append(", ".join(n for n, _, _ in stopped) + " entirely so")
    if notes:
        title += "\n" + "; ".join(notes)
    ax.set_title(title, loc="left", fontsize="medium")
    ax.legend(frameon=False, fontsize="small")
    ax.margins(x=0.04)
    fig.tight_layout()
    fig.savefig(path, dpi=200)
    print(f"\nwrote {path}")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Species and energies from Strata track files")
    parser.add_argument("filenames", nargs="+",
                        help="primaries and/or cascades files")
    parser.add_argument("--past", type=float, default=None, metavar="X",
                        help="count only tracks that reached x > X, in mm; "
                             "for tandem_stripper.mac the gas cell ends at 50")
    parser.add_argument("--csv", metavar="FILE", help="write the table as CSV")
    parser.add_argument("--plot", nargs="?", const="species.png", metavar="FILE",
                        help="histogram the exit energies")
    parser.add_argument("--no-charge", action="store_true",
                        help="leave out the charge-state note")
    args = parser.parse_args()

    tracks = read_tracks(args.filenames)
    if not tracks:
        sys.exit("no tracks read")
    events = len({t.event for t in tracks})
    rows = summarise(tracks, args.past)
    table = report(rows, events, args.past, not args.no_charge)

    if args.csv and table:
        import csv
        with open(args.csv, "w", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(table[0]))
            writer.writeheader()
            writer.writerows(table)
        print(f"wrote {args.csv}")

    if args.plot:
        plot(rows, args.past, args.plot)
