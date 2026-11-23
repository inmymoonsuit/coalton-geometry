# Changelog

Changes a caller can meet.

## 0.1.0 — 2026-11-23

The first module. New package `coalton-geometry/spline/basis`: `make-basis`, `evaluate!`
and `evaluate-batch!` give the B-spline basis functions that are not zero at a parameter
and their derivatives, into caller-owned arrays, with the refusals and the error bound of
[its contract](docs/spline-basis.md). [Batch 1's record](docs/batch1.md) has the
measurements.

## 0.0.1 — 2026-11-22

The repository is reserved and its groundwork laid: the system definition with no
component, the pinned toolchain and its check runner, the aliasing and scale-sweep rosters
with no member, a measurement of how a point can be stored, and the decisions open before
a first module. Nothing can be called.
