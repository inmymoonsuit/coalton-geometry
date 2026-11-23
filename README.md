# coalton-geometry

An independent geometry library written in
[Coalton](https://github.com/coalton-lang/coalton), for 64-bit SBCL, in double precision.
It offers B-spline basis functions and their derivatives to any order; the curves that are
their combinations, in any dimension, with their derivatives; and the parameter of a curve
nearest to a point, shown to be the nearest of the whole curve and reported as a tie where
the curve offers two. Each answer comes with an error bound derived before the code was
written, and every answer is tested against that bound in exact arithmetic.

The library takes knots, control points and points in arrays the caller owns, and writes
values, parameters and reports into arrays the caller owns. Tolerances, units and
conventions belong to the caller: nothing here chooses one. No application code is loaded
or required.

**Status: three modules built**, all of them on splines. Conics, rotations and measures
come next: [the batch plan](docs/plan.md) has what follows and [the roadmap](ROADMAP.md)
what each waits for.

| Package | What it gives | Contract |
| --- | --- | --- |
| `coalton-geometry/spline/basis` | The basis functions of a knot vector that are not zero at a parameter, and their derivatives to any order, into caller-owned arrays | [docs/spline-basis.md](docs/spline-basis.md) |
| `coalton-geometry/spline/curve` | A point of a curve in any dimension and its derivatives with respect to the parameter, with the basis rows that are its derivatives with respect to the control points | [docs/spline-curve.md](docs/spline-curve.md) |
| `coalton-geometry/spline/nearest` | For a batch of points, the parameter of the curve nearest to each, shown to be the nearest of the whole curve, with a report of an end, a tie or an answer that could not be shown | [docs/spline-nearest.md](docs/spline-nearest.md) |

It is the sister of [coalton-linalg](https://github.com/inmymoonsuit/coalton-linalg),
numerical linear algebra in Coalton, and is built to the same rules: contracts written
with each interface, refusals by name, storage owned by handles, nothing allocated in a
warmed call unless it is measured and said, and every claim tested against an independent
reference.

## What it is, and is not

- **It is** the geometry a numerical solver written in Coalton needs beside its linear
  algebra: points, directions and curves of the plane and of space, the quantities
  measured on them, and the predicates that decide which side, which order, how far.
- **It is not a modelling kernel.** No solids, no boolean operations, no topology.
- **It holds no application's policy.** No tolerance is chosen here, no unit, no constraint
  and no convention of a drawing. A caller that needs a tolerance passes it,
  and a call that cannot answer without one says so.
- **It may depend on coalton-linalg, never the reverse.**

## What is here

| Path | Purpose |
| --- | --- |
| `coalton-geometry.asd` | The library system and its test system |
| `src/` | The modules, one package a file |
| `tests/spline-basis.lisp`, `tests/spline-basis-callers.ct` | The basis module against its contract: an exact reference, every refusal, batches, allocation |
| `tests/spline-curve.lisp`, `tests/spline-curve-callers.ct` | The curve module against its contract, the same way |
| `tests/spline-nearest.lisp`, `tests/spline-nearest-callers.ct`, `tests/spline-nearest-reference.lisp` | The search against its promises, with an exact reference that isolates the roots of a polynomial in rationals |
| `tests/representation-subject.ct`, `tests/representation-callers.ct`, `tests/representation.lisp` | How a point can be stored, measured on the pinned compiler; [the design notes](docs/design.md) rest on it |
| `tests/aliasing.lisp`, `tests/scale-sweep.lisp` | The two [rosters](docs/rosters.md), which every exported call answers |
| `scripts/`, `tools/`, `toolchain.lock.json` | The check runner, the pinned toolchain it verifies, and the runner for planted defects |
| `tests/plants/` | Rosters of planted defects, one for each batch |
| `CONTEXT.md` | [The library's mathematical conventions and terms](CONTEXT.md) |
| `docs/` | [Design decisions](docs/design.md), [batch plan](docs/plan.md), [developing a module](docs/development.md), [provenance](docs/provenance.md), [reference texts](docs/references.md), [rosters](docs/rosters.md), the records of [the groundwork](docs/batch0.md), [batch 1](docs/batch1.md), [batch 2](docs/batch2.md) and [batch 3](docs/batch3.md), [toolchain](docs/toolchain.md), [setup](docs/setup.md) |

## Checking it

With the pinned dependencies installed and `config.local.psd1` pointing at them
([setup](docs/setup.md)):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1 -Safety 0
```

Run them one after the other. Each verifies the installed toolchain against the lock,
builds the library and its tests afresh, fails on any compiler warning, runs the tests
with the finalizer paused so that allocation can be counted, and verifies the systems that
were actually loaded.

## Licence

[MIT](LICENSE). The algorithms are written from published descriptions and never from
another implementation's code; [provenance](docs/provenance.md) has the rule and the
register.
