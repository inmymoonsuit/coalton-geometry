# Design decisions

The decisions every interface of this library will rest on. Each is written here before
the first module so that it is made once. **None is closed.** Where something has been
measured it is given; where there is a leaning it is called one.

## How a point is held

The question that shapes every call: is a point a value of its own, or two numbers at a
place in an array?

It was measured before anything was designed, because the sister library met the cost by
surprise: a helper returning one number allocated on every call until it wrote into an
array. [`tests/representation.lisp`](../tests/representation.lisp) runs the same small
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

What it says:

- **The compiler sees through small functions, across files.** A point passed and
  returned as a value by an operation of a few lines costs nothing, marked inline or not.
- **A point that is kept costs 32 bytes**, as any value stored on the heap does. A curve
  that holds a hundred control points as values holds a hundred allocations.
- **A call that is not seen into pays for every value crossing it**: 32 bytes for each
  point in or out, 16 for each number. The measurement reaches such a call by handing the
  function over in an array, which is the worst case; a routine too large to inline is
  the ordinary one, and the sister library measured 16 bytes there for one returned
  number. Every routine of substance in this library, a nearest-point search, an
  intersection, will be such a call.

**The leaning that follows**, not yet a decision: data that is held, and the results of
any routine of substance, live in arrays of coordinates that the caller owns, written at
an index, as the sister library's do; small operations on a few numbers may take and
return numbers. A point type of its own would then be a convenience at the edge, not the
currency. This is the arrangement under which the two rosters' membership rules already
make sense.

What is not measured: a routine of real size called by name, with several numbers in and
a few out; and whether several numbers can be returned at once without a box. Both belong
to the first module's contract.

## What a predicate returns

An orientation, a side, an order. The sign of a small determinant computed in floating
point is wrong near zero, and near zero is where it is asked.

- **Leaning**: a predicate returns the exact sign or refuses. It does not return the sign
  rounding happened to give. The first stage is a floating-point evaluation with a proved
  error bound that settles nearly every case; what it cannot settle goes to an exact
  evaluation.
- **Open**: whether the exact stage is built here, in what arithmetic, and what its
  allocation contract is, since an exact stage that allocates breaks the rule that a
  warmed call takes no storage. A predicate that reports "too close to say" and leaves
  the exact answer to the caller is the alternative.

## Who owns a tolerance

- **Decided in principle, by the boundary in the README**: the library chooses none. A
  call that needs one takes it as an argument, in the units of its inputs, and says in its
  contract what it is compared with.
- **Open**: whether a tolerance may ever be relative, and to what.

## What a degenerate input gets

Two points that coincide, three on a line, a radius of zero, parallel lines, a direction
of length zero, a parameter at the end of its range.

- **Leaning**: each is a named outcome of the call, in its status, never a number that
  happens to come out and never a silent choice of one answer among many. Where a
  derivative does not exist the call says so and does not return one.
- **Open**: how near to degenerate counts, which is the tolerance question again, and
  whether nearness is the library's to judge at all or only exact degeneracy is.

## Derivatives

A solver differentiates everything it is given. A nearest-point parameter has a derivative
with respect to the point and to the curve, by the implicit function theorem, and it
ceases to exist where the nearest point jumps.

- **Leaning**: a routine whose result a solver will differentiate returns its derivatives
  with it, computed from the same intermediate values, with the places where they do not
  exist named.
- **Open**: the layout of a derivative in a caller-owned array, and whether second
  derivatives are ever wanted.

## Conventions

To be fixed in a glossary with the first module, and listed here so that none is fixed by
accident: radians; right-handed axes; counter-clockwise positive in the plane; column
vectors; how a rotation is stored and which of a quaternion and its negative is returned;
how an arc's direction and a curve's parameter range are given.

## Dependency on the sister library

- **Leaning**: allowed, one way, and taken only when a module needs it: a small dense
  solve, an eigenvalue problem of a conic. Predicates and measures need none.
- **Open**: whether a module that needs none should be loadable without it, which would
  make this more than one system.
