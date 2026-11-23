# coalton-geometry

Geometry in [Coalton](https://github.com/coalton-lang/coalton), as a library of its own.

**Status: reserved. No geometry is built yet.** This repository holds the groundwork a
first module will stand on: a pinned toolchain that compiles and checks, the two rosters
that every exported call will have to answer, one measurement that decides how a point is
stored, and the decisions still open. [The roadmap](ROADMAP.md) says what is waited for
before the first module.

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
| `coalton-geometry.asd` | The library system, with no component yet, and its test system |
| `tests/representation-subject.ct`, `tests/representation-callers.ct`, `tests/representation.lisp` | How a point can be stored, measured on the pinned compiler; [the design notes](docs/design.md) rest on it |
| `tests/aliasing.lisp`, `tests/scale-sweep.lisp` | The two [rosters](docs/rosters.md), with no member yet |
| `scripts/`, `tools/`, `toolchain.lock.json` | The check runner and the pinned toolchain it verifies |
| `docs/` | [Design decisions](docs/design.md), [provenance](docs/provenance.md), [rosters](docs/rosters.md), [toolchain](docs/toolchain.md), [setup](docs/setup.md) |

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
