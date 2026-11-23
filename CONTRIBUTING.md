# Contributing

The library is reserved: [the roadmap](ROADMAP.md) says what a first module waits for.
Until then a contribution is an answer to one of [the open decisions](docs/design.md), a
measurement that bears on one, or a correction.

A module, when one is added, comes whole: its contract in `docs/`, its source as a `.ct`
file under `src/`, its tests against an independent reference, its entries in both
rosters, and a record of what was measured. Changes to numeric behaviour, ownership or a
refusal are interface changes and update the contract and its tests together.

Use the configured toolchain and `scripts/check.ps1`. Run one build or test job at a time
on a shared machine. Keep allocation checks distinct from numerical correctness and from
timing.

## Four questions for every numeric routine

An outside audit of the sister library found eight defects that every test then in its
suite passed. Each was the answer to one of four questions that had not been asked of the
routine. They are asked here from the first routine on.

1. **Can an intermediate value overflow or underflow when the result is
   representable?** A squared distance, a product of two lengths, a determinant: each can
   leave the range of the format while the value the caller wants is well inside it.
   Scale before combining, or carry the exponent apart from the significand.
2. **What happens when two array arguments are one array?** The call either does exactly
   what it does with two arrays of equal contents, or refuses before it writes.
3. **Is work done for a step that will not be taken?** Preparing the next step after the
   last one allowed can cost a caller's evaluation, and can turn a finished answer into a
   refusal when that preparation fails.
4. **Is anything allocated or written before a refusal?** Sizes and finiteness are
   checked before the first allocation and the first write, so a refused call leaves its
   outputs as they were and takes no storage.

The first two are asked by test, of every exported call at once:
[the rosters](docs/rosters.md) read their members from the sources, so a call joins by
being declared and the suite fails until it is answered for. The last two are answered in
each routine's own tests.

Geometry adds a fifth, which the design notes take up: **what does the call do with a
degenerate input**, two points that coincide, three on a line, a radius of zero? It
answers by name. It does not return a number that happens to come out.

## Clean room

A published method may be implemented from its description: the mathematics, the prose,
the error analysis. Another implementation's code is never consulted or copied, whatever
its licence, and that includes code published beside a paper. Record every source and its
licence in [provenance](docs/provenance.md) before the code that uses it lands.

## Evidence

Generated logs, compiled caches and local configuration are not source and stay under
ignored locations. A record states the revision and toolchain, the command, the counts,
the failures and the limits.

Contributions are under the project's [MIT licence](LICENSE).
