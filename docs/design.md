# Design decisions

The decisions every interface of this library rests on, made once, before the first
module. Each says whether it is **decided** or **open**, and a decided one says on what
evidence and who agreed. The first consumer of the library and the session that reviews
its batches signed the decided ones on 2026-11-22, each with terms that are written in.
The maintainer of the sister library was asked and had not answered when this was
written.

## Scope — decided

General geometry for a numerical solver: curves, rotations, distances and angles, each
with its derivatives, in [the order a first consumer expects to need them](../ROADMAP.md).

- Not a modelling kernel: no solids, boolean operations, topology or freeform surfaces.
- **No application's convention.** No tolerance, unit, drawing or modelling convention is
  chosen here, and none is ever taken as a mode of a call. Where an application and the
  mathematics both give a right answer and differ, the application applies its convention
  on its own side of the call.
- **The library has mathematical conventions, and states each once in the contract it
  belongs to**: a parameter's domain and direction, an angle's range, which of a
  quaternion and its negative a logarithm returns. Those are the library's to choose.

## How a point is held — decided

**Held data, and the results and derivatives of every routine, live in arrays of
coordinates that the caller owns, written at an index. A routine that is called once for
each of many points takes them as a batch.** A point as a value of its own is at most a
convenience for small operations on a few numbers.

The evidence is a measurement and a consumer. It was measured before anything was
designed, because the sister library met the cost by surprise: a helper returning one
number allocated on every call until it wrote into an array.
[`tests/representation.lisp`](../tests/representation.lisp) runs the same small
computation each way, a hundred thousand times in a compiled loop, and counts the bytes.
The operations live in one file and package and their callers in another, as a library
and its consumer do; an earlier version with both in one file measured nothing at all and
would have misled.

| A midpoint or a cross product, computed as | Bytes a call |
| --- | --- |
| A point as a value, returned by a small function | 0 |
| The same, the function marked inline | 0 |
| A number returned by a small function | 0 |
| Points in one array of coordinates, written at an index | 0 |
| A point as a value, **kept** in an array of points | 32 |
| A point as a value, through a function the caller cannot see into | 96 |
| A number, through a function the caller cannot see into | 80 |

Measured on the pinned compiler at both safety policies, and pinned by the test.

- **The compiler sees through small functions, across files.** A point passed and
  returned as a value by an operation of a few lines costs nothing.
- **A point that is kept costs 32 bytes**, as any value stored on the heap does.
- **A call that is not seen into pays for every value crossing it**: 32 bytes for each
  point in or out, 16 for each number. The measurement reaches such a call by handing the
  function over in an array, which is the worst case; a routine too large to inline is
  the ordinary one, and the sister library measured 16 bytes there for one returned
  number. Every routine of substance here, a nearest-point search, an intersection, is
  such a call, and one made for every held point at every step of a solver.

The consumer holds every coordinate in flat arrays of doubles already and makes no point
objects, so the arrangement costs it nothing to adopt. A batch pays the price of the call
once a step and not once a point.

**A batched call that refuses says which element refused, by its index, and whether
anything was written.** Refusing the whole batch before the first write is acceptable. A
result written in part with no index is not.

Not measured, and owed with the first module's contract: a routine of real size called by
name, with several numbers in and a few out.

## Derivatives — decided

A solver differentiates everything it is given.

- **A routine whose result a solver will differentiate returns its derivatives with it**,
  into caller-owned arrays, computed from the same intermediate values.
- **Derivatives are analytic, never finite differences.** A parameter found by a search
  has its derivative by the implicit function theorem.
- **Where a derivative does not exist the call refuses by name and returns no number**: a
  cusp, a nearest point at the end of a parameter's range, a rotation's logarithm at a
  half turn, where the axis turns.

**Open**: the layout of a derivative in its array, and whether second derivatives are
wanted.

## A branch is reported — decided

**A routine whose answer branches says so to its caller. It does not silently pick one.**
A nearest-point search reports a nearest point that is not unique, or one that sits where
the answer switches from one branch to another. A consumer that steps back from such a
place can only do so if it is told.

This is the same rule as for a degenerate input, below, seen from the output.

## What a degenerate input gets — decided in principle

Two points that coincide, three on a line, a radius of zero, parallel lines, a direction
of length zero, a parameter at the end of its range.

- **Each is a named outcome of the call, in its status.** Never a number that happens to
  come out, and never a silent choice of one answer among many.
- **Open**: how near to degenerate counts. Exact degeneracy is the library's to detect;
  nearness needs a tolerance, which is the caller's, so a call that judges nearness takes
  the tolerance and says what it compares it with.

## Who owns a tolerance — decided

The library chooses none. A call that needs one takes it as an argument, in the units of
its inputs, and its contract says what it is compared with.

**Open**: whether a tolerance may ever be relative, and to what.

## What a predicate returns — open

An orientation, a side, an order. The sign of a small determinant computed in floating
point is wrong near zero, and near zero is where it is asked. No predicate is on the
consumer's list, so this waits.

- **Leaning**: a predicate returns the exact sign or refuses. A first stage in floating
  point with a proved error bound settles nearly every case; what it cannot settle goes
  to an exact evaluation, or is reported as too close to say.
- **Open**: whether the exact stage is built here, in what arithmetic, and what it may
  allocate.

## Dependency on the sister library — decided

**The direction is fixed: this library may depend on coalton-linalg, and coalton-linalg
never depends on this one. No dependency is declared until a module needs one.**

The first three ranks of the consumer's list were gone through, by this library's author
and independently by the consumer against what it will call. None needs general linear
algebra:

- B-spline bases are recurrences, and a global start is a subdivision.
- A nearest parameter is a scalar Newton iteration, and its derivative by the implicit
  function theorem is a scalar division.
- Ellipse and parabola quantities are closed forms or scalar roots.
- Rotations are closed forms on three-by-three matrices and quaternions.
- A nearest point on a surface, later, needs a two-by-two solve, which is a closed form.

**Closed forms of a fixed small size belong here.** They are not the second linear algebra
the roadmap refuses, which is anything of general size. What would bring the dependency
in is fitting, spline interpolation or the eigenproblem of a conic, and none is asked
for. Adding a dependency later breaks no caller. Declaring one now would make every
consumer load the sister library for nothing and tie the two libraries' versions
together.

## Agreement with an implementation a consumer already has — decided

A consumer may have an implementation of its own that its results must agree with.

- **This library's authors never read it.** It is another implementation, and
  [the provenance rule](provenance.md) is that none is consulted.
- **Agreement is judged from outside**, by the consumer's own test, and a difference is
  reported as: the inputs and both sides' outputs as exact doubles, a reference value
  computed from the mathematics in exact or high-precision arithmetic and never taken
  from either side, each side's distance from it, the clause of the contract that
  applies, and the convention in play stated as mathematics.
- **Where one side is wrong by the mathematics, that side changes**, whichever it is.
  Where both are right and differ, the difference is the consumer's to reconcile on its
  own side.

## Conventions — open

To be fixed in each contract and gathered in a glossary with the first module; listed here
so that none is fixed by accident: radians; right-handed axes; counter-clockwise positive
in the plane; column vectors; how a rotation is stored and which of a quaternion and its
negative is returned; how an arc's direction and a curve's parameter range are given.
