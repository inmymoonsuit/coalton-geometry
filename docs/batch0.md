# Batch 0: groundwork

State: completed 2026-11-22; both complete checks pass at safety 1 and safety 0 on
Windows x86-64, SBCL 2.6.10 and the pinned Coalton compiler. No geometry is built.

## What this is

Everything a first module needs to exist before it does, so that the first module is only
a module.

## What was built

- **A repository that checks itself.** The system definition with no component;
  `scripts/check.ps1`, which verifies the installed toolchain against a content lock,
  builds the library and its tests afresh, fails on any compiler warning, runs the tests
  with the finalizer paused, and verifies the systems that were loaded. Carried over from
  the sister library and cut down to what applies. The first run was from an empty cache.
- **The two rosters, with no member.** Their machinery and their own controls run on every
  check. A call added to the library is read from the sources and has to be answered for.
- **A measurement of how a point can be stored**, pinned by a test.
- **A runner for planted defects**, `tools/plants.py`, and its first roster. In the sister
  library those were scripts kept outside the repository and run by hand; here they are
  tracked, so a batch's controls can be run again by anyone.
- **The decisions**: [scope and design](design.md), [provenance](provenance.md),
  [conventions](../CONTEXT.md), signed by the library's first consumer, the session that
  reviews its batches and the session that builds the sister library.
- **The plan**: [the batches](plan.md), and [a draft contract](spline-basis.md) for the
  first.

## What was measured

How many bytes a call allocates, for the same small computation written each way, a
hundred thousand calls in a compiled loop:

| Computed as | Bytes a call |
| --- | --- |
| A point as a value, returned by a small function | 0 |
| The same, the function marked inline | 0 |
| A number returned by a small function | 0 |
| Points in one array of coordinates, written at an index | 0 |
| A point as a value, kept in an array of points | 32 |
| A point as a value, through a function the caller cannot see into | 96 |
| A number, through a function the caller cannot see into | 80 |

The same at both safety policies. [The design notes](design.md#how-a-point-is-held--decided)
say what was concluded.

**The first version of this measurement was wrong, and passed.** With the operations and
their callers in one file every row read zero: the compiler saw through all of it. Moved
into two files and two packages, as a library and its consumer are, the small operations
still read zero, which is a real finding, and the last three rows appeared. A function
the caller cannot see into is reached by handing it over in an array; this compiler has no
way to forbid inlining by name.

## Verification

- **Both complete checks** pass, the first from an empty cache: 18 toolchain components
  and 1,315 files match the lock, 27 dependency systems are loaded from pinned sources,
  and the checker's six planted mismatches are rejected.
- **The measurement sees an allocation**: a loop making one cons a call reads 16 bytes.
- **Each roster's own controls**: a member the sources would add is reported; a call that
  reads what it has overwritten and a refusal after a write are reported and a call that
  is right with one array is not; each class of the scale sweep is produced by a planted
  run; an entry answering for a call it does not make is refused.
- **Planted defects**, through the tracked runner:

| Planted | Verdict |
| --- | --- |
| The midpoint written into the array is a quarter of the sum | caught |
| The cross product adds its two products | caught |
| A point that should be kept is not, so nothing is allocated | caught |
| A declaration that does not match its definition, the runner's own control | invalid, as it must be |

## Limits

- **Nothing can be called.** Every check here is of machinery.
- **The rosters have never met a member of this library.** They were proved on the sister
  library's calls, 25 and 82 of them; here only their controls run.
- **A routine of real size called by name is not measured.** The costly rows of the table
  are a worst case, a function known only by its type.
- **The lock is the sister library's**, copied on the day. The two are checked on one
  toolchain and will have to move it together.
- **One platform**: 64-bit SBCL on Windows. No hosted continuous integration.
