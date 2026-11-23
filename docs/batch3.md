# Batch 3: the nearest parameter of a curve to a point

State: completed 2026-11-23; both complete checks pass at safety 1 and safety 0 on
Windows x86-64, SBCL 2.6.10 and the pinned Coalton compiler. The library's first
consumer has reviewed the code with a reference and tests of its own and found no defect:
[below](#the-consumers-review).

## What was built

Package `coalton-geometry/spline/nearest`, in [`src/spline/nearest.ct`](../src/spline/nearest.ct),
to [its contract](spline-nearest.md): `make-search`, a handle for one basis and one
dimension that owns every workspace, and `nearest!`, which for a batch of points against
one array of control points writes the parameter of the curve nearest to each, a report of
what kind of answer it is, and four measures: the distance, the residual, a bound on the
residual's error, and the speed of the curve there.

`differentiate!`, the derivatives of the foot, is specified in the contract and **not
built**: the consumer does not need it for its first use, and it gets a batch of its own.

The module calls the curve module through its public interface. Its tests are
[`tests/spline-nearest.lisp`](../tests/spline-nearest.lisp) with compiled callers in a
file and a package of their own, against an exact reference in
[`tests/spline-nearest-reference.lisp`](../tests/spline-nearest-reference.lisp); it has
its entries in both rosters and [a roster of planted defects](../tests/plants/batch3.py).

## Where the method was read

Almost none of it was. [The register](provenance.md#the-register) has the one property
taken from a text, that a segment of a curve lies in the convex hull of the control points
of its span and its derivative in the hull of its own (Prautzsch, Boehm and Paluszny, 5.7,
p. 69, and 5.6, p. 67). Everything else is derived in the contract, which the consumer
checked by hand before any source was written and had two constants corrected.

## What was measured

### Against the exact reference

On each span a curve is a polynomial with rational coefficients, and so is the residual of
its distance from a point. The reference counts and isolates the real roots of that
polynomial exactly, by a Sturm chain in rationals, so every least point of the distance is
known to any precision: it uses no bound over an interval, no halving and no Newton step.
Each answer of the module was then held to the contract's promises as they are written.

| | |
| --- | --- |
| Curves | 28, of degrees 2 to 5, in one, two and three dimensions |
| Answers checked | 357, each curve searched with no hint, with its own answers as hints, and with hints that are wrong or outside the domain |
| Interior feet | 249 |
| Ends of the domain | 81 |
| Ties reported | 22, every one a tie in the reference to within the tolerance given and a part in a million |
| Left unresolved | 5, all of them where the reference says there is no single answer, no work was allowed, or a greatest distance lay within the tie |
| Within the step of the exact least point | 237 |
| Certified by a residual within its bound alone | 34 |

The curves are on knots clamped and not, even and uneven, with interior knots repeated as
often as the search allows, and one family lies 10^6 from the origin, where the point of a
curve is small beside its control points. For each answer the test checks that the
parameter is within the step of a least point or has a residual within twice its bound;
that the least point it belongs to is the nearest; that every other least point is farther
than the returned distance by more than the tie, wherever no tie is reported; that a
reported tie is one; that the residual returned is within its returned bound of the exact
residual at the returned parameter; and that the report goes with the parameter.

### Answers known in advance

A cubic that bends back, seen from its axis of symmetry: two feet as near as each other,
reported as a tie; moved off the axis by a thousandth, one foot, and a tie again when the
tolerance is wider than the difference. A curve confined to a line and crossed twice by
the point: a tie, which is the case that showed the first rule for a tie to be wrong. Points beyond each end: the end, exactly. A point
of the curve: a foot at distance zero. A foot that is an interior knot of a straight curve:
one foot and not a tie, with no halving allowed, since the candidates of the two spans that
meet there are one least point. A curve that is a single point: unresolved, ended by the
budget. A bent curve with no halving allowed: unresolved. A second least point ten times
farther, with a tie wide enough to take it in: a tie; with a narrower one, a foot; and
with one so wide that the greatest distance between the two is within it, unresolved.

### Refusals

Every basis a search cannot be made for; every size, each tolerance below zero, not a
number or without bound, and a control point, a point or a hint that is not finite, each
with nothing written; the order in which those are asked; a hint outside the domain, which
is no error; and each of eight ways an output can be an input or the other output.

### Allocation

Through a loop compiled in another file and another package, at both safety policies: 0
bytes for a call of six points, with hints and without. A batch is its points, bit for bit.

### The scale sweep

A parameter is promised to within the step, not bit for bit, so these two entries are
compared to 10^-10. A point left unresolved is counted as a refusal of the run.

| Entry | Across the sweep |
| --- | --- |
| The curve and the points scaled | exact from 2^-400 to 2^400. Below 2^-510 the residual, a product of two lengths, is below the normal range; from 2^-600 and from 2^512 every point is unresolved because an answer's measures cannot be held. At 2^510 every point is unresolved although its measures could be held: the search's limit |
| The knots scaled | exact from 2^-300 to 2^300, within the step at 2^-400. Beyond, every point is unresolved, and from 2^-800 to 2^-510 and from 2^400 to 2^800 that is a limit: the answers could be held, and what underflow could have lost is what the bounds consist of |

**No run returns a wrong parameter at any scale.** Outside its range the search says that
it could show nothing.

### The aliasing roster

`nearest!` is a member. With four control points and two points of the plane, the control
points and the measures have one length, and so have the hints and the parameters; each
pair has an output in it and is refused.

## What the planted defects showed

Fifteen edits to the module's source, each applied alone and each caught:
`python tools/plants.py tests/plants/batch3.py`.

| Planted | Noticed first by |
| --- | --- |
| An interval set aside by the distance at its middle, with nothing for how far the curve can go | the refusals, whose accepted calls check their answers |
| The tie left out of the test that sets an interval aside | the known answers |
| An interval taken to rise wherever the residual at its middle is above its own error | the known answers |
| An interval taken to be convex wherever the gain is above zero | the known answers |
| A second candidate judged by the distance at its parameter, not at its least point | the known answers |
| Two candidates of convex intervals that touch taken for two least points | the refusals |
| The start of the domain never reported as the start | the refusals |
| A parameter returned for a point left unresolved | the known answers |
| A bracket taken for closed a million times too soon | the family against the reference |
| Measures taken to be three numbers a point | the refusals |
| A tie of minus one accepted | the refusals |
| The hints not looked at for a number that is not finite | the refusals |
| The parameters allowed to be the array of hints | the refusals |
| The speed of a span taken to be a quarter of its bound | the refusals |
| An interior knot allowed as often as the degree, where the tangent can turn | the refusals |

**The first run of this roster missed two of sixteen.**

- *The tie left out of the test that sets an interval aside* was missed because no fixture
  had a second least point that was within a tie, much farther than the nearest, and looked
  at after the nearest was known. One was added, and it is caught.
- *The left end of every convex interval offered as a least point* was missed because it
  changes nothing that can be seen: such an end is either merged with the candidate of the
  convex interval it touches, or lies in what the test by distance has already set aside.
  It was taken out of the roster, and the roster says why.

The fifth plant is the flaw the reference found. It was caught at first only by a curve
from the fixed random sequence, which a change to any fixture before it could have moved;
the case is now among the known answers, and the plant was run again against it.

**No plant removes the budget.** It would make the checks run without end.

## What the building found

Each is in the contract, marked where it stands, for the consumer's review.

1. **The tie rule was wrong, and the consumer's hand-check had passed it.** The derivation
   compared the distances computed at two returned parameters. A returned parameter is
   only within the step of its least point, which along a curve of speed 9 is a distance
   of 4 × 10^-12; on a curve confined to a line and crossing a point twice, the two
   computed distances were 4 × 10^-12 and 2 × 10^-15 where both least points are at zero,
   and an exact tie was reported as a single foot. The exact reference caught it, on a
   random curve and not on a designed one. Each candidate now carries a lower bound of the
   distance at its least point, derived from the convexity that was already shown.
2. **A depth does not bound the work.** With nothing set aside the intervals double at
   every halving, and at a depth of 60 a search did not end. A search now takes a budget of
   intervals too. A planted defect that removed it would hang the checks, so there is none;
   the single-point curve of the tests is what ends by it.
3. **Underflow.** Every bound of the derivation is a product somewhere, and a product that
   underflows makes it too small. A second device adds a small number wherever one is
   formed; the sweep then shows the range of scales, and no wrong answer outside it.
4. **The rule for taking a Newton step** as first written made every other pass a
   bisection. It is now that the step is at most half the one before.
5. **A chapter named to be read was not read.** The draft's provenance named a chapter on
   Newton's method in floating point. Nothing in the search rests on it, and the contract
   now says what the search's step is derived from.

## The consumer's review

Held back from the author and run on the commit as pushed, 2026-11-23. Its figures, as it
reported them:

- 2,574 checks, none failed, and no compiler warning.
- **A reference of its own, by a third route**: each span's squared distance as an
  interpolated rational polynomial, its derivative in Bernstein form, the roots isolated
  by exact subdivision with Descartes' rule on the coefficients and narrowed by exact
  bisection to 2^-90. This library's reference uses a Sturm chain; neither uses the
  module's bounds.
- Exact ties by construction, a curve of one dimension folding back and two symmetric
  curves of the plane with the point on the axis, at a tie of 10^-9, of zero, and of zero
  with a step of 10^-6; curves of the plane with no hint, the right one and a wrong one;
  degrees 2 to 5 and dimensions 1 to 3, a third of them 10^6 from the origin. Reports: 503
  feet, 42 starts, 54 ends, 37 ties, none unresolved.
- **The floor of a candidate, checked by hand and found sound**, with the rounding of the
  code that forms it: the drop is raised by the margin before the subtraction and the root
  lowered after.
- Three plants of its own, all caught: the original flaw; ties never reported; and the
  speed of a span halved, by which a symmetric tie was missed and nearest points lost.
- **Its own first run did not catch the original flaw either.** Its tie cases converged to
  the crossing exactly, so the two computed distances agreed and the flaw could not show;
  cases with a coarse step were added for it. That is the same thing this record found
  from the other side: the flaw shows only where a returned parameter is not the least
  point.

It accepted the budget and the two limits this record states, that a greatest distance
within the tie leaves a point unresolved and that ties are over-reported only; it hands a
step back on both. The underflow device and the rule for a Newton step it did not speak of
apart from finding no defect.

## What went wrong in the tests themselves

- **The first full pass took 514 seconds.** A chain of polynomial remainders in rationals
  grows its numbers at every step. Each is now replaced by the multiple of itself with
  whole coefficients that have nothing in common, and a root once isolated is narrowed by
  the sign of the polynomial alone; the whole suite takes about half a minute.
- **That change had a defect of its own**: for a remainder that is a single number the
  common factor came back with its sign, and the chain lost a sign. The reference's own
  checks hung on it. It is fixed and pinned by a check.
- **The reference was written and committed before any source**, as the order of work
  asks.

## Limits

- **No timing was taken.**
- **The derivatives of the foot are not built.**
- **A range of scales**, as the sweep gives it.
- **Curves of degree 1 and curves with a knot where the tangent can turn are refused.**
- **Ties are over-reported at the margin, never under-reported.** A point whose two least
  distances differ by about the rounding of a distance is reported tied.
- **A greatest distance within the tie of the least leaves a point unresolved.** The
  tests set an interval aside for being too far, for rising or falling, or for being
  convex; around a greatest value of the distance it is none of those. With no tie, or a
  small one, such an interval is too far and is set aside. A test for an interval on which
  the squared distance is concave, which holds no least point, would resolve it and is a
  candidate for the batch that adds the derivatives.
- **Degrees above 5 and dimensions above 3 were not tested**, though the contract allows a
  dimension up to 256.
