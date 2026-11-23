# Batch 1: B-spline basis functions

State: completed 2026-11-23; both complete checks pass at safety 1 and safety 0 on
Windows x86-64, SBCL 2.6.10 and the pinned Coalton compiler. The library's first consumer
accepted the contract as built on 2026-11-23, and its own review of the code, with tests
this library's author did not see, found no defect: [below](#the-consumers-review).

## What was built

Package `coalton-geometry/spline/basis`, in [`src/spline/basis.ct`](../src/spline/basis.ct),
to [its contract](spline-basis.md): a handle made once for a degree, a knot vector and a
highest derivative order; `evaluate!` for one parameter and `evaluate-batch!` for many,
writing the basis functions that are not zero on the parameter's span, and their
derivatives, into caller-owned arrays; six statuses, eight typed errors, and readers for
what the handle holds.

Its tests are [`tests/spline-basis.lisp`](../tests/spline-basis.lisp), with compiled
callers in a file and a package of their own, and it has its entries in both rosters and
[a roster of planted defects](../tests/plants/batch1.py).

## Where the method was read

[The register](provenance.md#the-register) has the four entries, cited to the page and
the equation. The reviewer reads these places:

| What | Where |
| --- | --- |
| The recurrence, and the convention for knots that coincide | Prautzsch, Boehm and Paluszny, 5.3, pp. 61 to 62 |
| The derivative | The same, 5.6, p. 67, equation (1); 5.7, p. 68 |
| The identity the exact reference is solved from | The same, 5.12, p. 75, Problem 4; 5.8, p. 69 |
| The model of rounding the bound is stated in | Higham, second edition, (2.4) p. 40, Lemma 3.1 p. 63, (2.8) p. 56 |

Every one is mathematics and prose. The text has no listing, so no comparison of
statement order is owed. How the computation is arranged was not read anywhere; the
register says what the arrangement is.

## What was measured

### Against the exact reference

Every number the module returns was compared with its exact value, computed in rationals
from Marsden's identity as a linear system, with no recurrence in it. The tolerance was
the contract's bound and nothing looser.

| | |
| --- | --- |
| Knot vectors | 305, of degrees 1 to 6 |
| Parameters | 7,804 |
| Evaluations compared | 41,776 |
| Numbers compared | 888,461 |
| Worst error of a value | 0.274 of its bound |
| Worst error of a derivative | 0.223 of its bound |

The knot vectors are clamped and unclamped, uniform and uneven by up to 2^60 between
neighbouring spans, on spacings that are and are not powers of two, near the origin and
far from it, with every multiplicity the contract permits inside the domain and at its
ends, an interior knot where the basis jumps among them. Each is tried at every knot of
its domain, at the doubles on each side of every knot, at four points inside every span,
at both ends of the domain and at the doubles just outside them, and at every order from 0
to one above the degree. Where a call should refuse, which span a parameter belongs to and
how many times a knot is repeated are worked out in the test from the definitions and not
asked of the module.

Two worst-case figures are for errors that rounding accounts for. An error that needed
the bound's underflow term is counted apart: 2,618 values and 5,151 derivatives in those
families, all at parameters within a subnormal distance of a knot at zero.

**How weak the derivatives' bound can be.** `S`, the size a derivative would have if its
terms did not cancel, was at most 2^1074 times the derivative it bounds. That extreme is a
first derivative one subnormal step from a knot, where the derivative itself is nearly
zero; it is the bound being correct and saying little, which the contract warns of.

### At the extremes of the format

Six knot vectors whose spans differ by more than a quotient of them can hold, or which
lie wholly among the subnormal numbers, tried the same way: 327 evaluations, 2,494
numbers, all within the bounds, 62 values and 27 derivatives needing the underflow term.
134 calls were refused as too large to hold, and the test confirmed for each that a term
of the derivative asked for does reach the largest double.

### The identities

In every evaluation above: each value at least 0 and at most `1 + γ(5p)`; the values
summing, exactly, to within the bound of 1; each row of derivatives summing to within the
bound of 0; every order above the degree exactly zero.

### Refusals

Each of the seven rules for a knot vector, with the number it carries, and the order they
are asked in. Each status of a call, with the output and the latest span checked to be
untouched. A batch with one parameter that cannot be evaluated, at its first position, in
its middle and at its end, with a second bad parameter after it: refused with nothing
written and the first one reported. A batch is its single calls bit for bit.

### Allocation

Counted through loops compiled in another file and another package, at both safety
policies, with the finalizer paused:

| | Bytes |
| --- | --- |
| A round of six `evaluate!` calls to the second order | 0 |
| An `evaluate-batch!` of six parameters to the second order | 0 |
| A round of two `evaluate!` calls, one of them refused | 0 |

### The scale sweep

Knots and parameters multiplied by a power of two, at twenty-five scales from 2^-1020 to
2^1020.

| Entry | Across the sweep |
| --- | --- |
| A basis and what it reads back | exact everywhere |
| Values and spans | exact everywhere |
| Derivatives to the second order | refused from 2^-1020 to 2^-512, where the second derivative is too large to hold; exact from 2^-510 to 2^400; lost from 2^510, where it is too small to be a normal number |

No run is a `:limit`: the module refuses only where an answer cannot be held. The
derivatives' entry has a tolerance of 10^-15 for the edge of the range. At 2^510 some
second derivatives are still normal numbers while the quotients they are differences of
are not, and those come back within a few last places and not exactly; with no tolerance
that run is `:wrong`. That is the underflow term of the bound, seen from the other side.

### The aliasing roster

One call takes more than one array. Its parameters and its output can be one array only
when there is no parameter, and it refuses that.

## What the planted defects showed

Nineteen edits to the module's source, each one a mistake a reader could make that still
compiles, each applied alone and each caught: `python tools/plants.py tests/plants/batch1.py`.

| Planted | Noticed first by |
| --- | --- |
| The second weight formed as one less the first, which the contract forbids | the error bound on a value |
| A parameter equal to a knot placed in the span on its left | the refusals |
| The end of the domain not given to the last span | the family against the reference |
| The last span taken to be the first one | the refusals |
| A derivative multiplied by one less than the degree it has reached | the error bound on a derivative |
| A derivative's difference taken the other way round | the error bound on a derivative |
| One derivative more allowed at a repeated interior knot | the refusals |
| The shortcut for knots that are not repeated taken one order too far | the refusals |
| A batch checked only as far as its first parameter | the batch tests |
| A parameter above the domain let through | the refusals |
| Orders above the degree left as the caller's array had them | the family against the reference |
| A knot allowed one repeat more than the degree and one | the knot rules |
| A knot equal to the one before it refused as decreasing | the knot rules |
| The output of one evaluation allowed to be the basis's own knots | the refusals |
| The output of a batch allowed to be its array of parameters | the aliasing roster, and nothing else |
| A derivative too large to hold delivered as it is | the refusals |
| The latest span cleared by a call that is then refused | the refusals |
| The position of a refused parameter reported one late | the batch tests |
| The length of an output accepted when it is too long | the refusals |

The first is the one the contract's error bound turns on: with the second weight written
as one less the first, a value beside a knot is off by more than its bound, and the test
says by how much.

**A twentieth was not a defect, and that is a finding.** The source as first written
marked `evaluate!` inline, on the expectation that its parameter, a number, would
otherwise be boxed where it crosses the call. With the mark removed the allocation
measured is still zero. The mark was taken out, the plant with it, and the two complete
checks this record rests on are of the source without it.

## What the building found

Each of these is marked *as built* in [the contract](spline-basis.md#as-built-what-changed-from-the-accepted-text).
The consumer accepted them all, and checked the derivation of the first by hand.

1. **The derivatives' bound needed an underflow term.** The accepted contract set
   underflow aside for derivatives and said the tests would show whether an admitted input
   reaches it. One does, on the first run of the family: a parameter one subnormal step
   from a knot, where the computed derivative was 0 and the exact one was the least
   positive number. The term `U` was then derived, by carrying what underflow can lose
   through the same steps as `S`, and every number passes with it.
2. **A derivative can be refused as too large when only a term of it is.** The module
   forms a derivative as a difference of quotients. Where both overflow, their difference
   is not a number, although the exact derivative might have fitted. The contract now says
   so, and the test admits the refusal only where `S` reaches the largest double.
3. **A single evaluation writes nothing on that refusal**, since it is computed in the
   handle's workspace first. The accepted contract had allowed it to leave the output
   unspecified.
4. **The borrowed view of the knots is an array a caller can pass back as an output.** It
   would overwrite the handle's knots. The aliasing roster cannot see it, since it is not
   an argument of the call that reads it. It is refused as a typed error and tested here.
5. **The value at an interior knot repeated `p + 1` times is refused**, where the basis
   jumps: the accepted rule read for order zero.
6. **The cost of derivatives is quadratic in the order**, not linear as the accepted text
   said.

## The consumer's review

Held back from the author and run on the commit as pushed, 2026-11-23. Its figures, as it
reported them:

- 57,053 checks against exact rational arithmetic, none failed, and no compiler warning.
- Its own cubics at every knot and on either side; 120 random knot vectors of degrees 1 to
  5 with multiplicities, spacing over 40 binades, clamped and not; knots near the bottom
  of the range and parameters a subnormal distance from a knot; a batch against its single
  calls bit for bit; the scale law from 2^-400 to 2^400; every refusal and both aliasing
  errors.
- Every value and derivative held to the contract's bound, with `S` and `U` computed from
  the contract's formulas. Its worst errors, as fractions of the bound: 0.41 for a value,
  0.40, 0.36 and 0.31 for the first three derivatives. Those are worse cases than this
  record's own 0.27 and 0.22, found by inputs the author did not choose, and still inside.
- Each refusal as too large to hold checked to have an exact `S` at or above the largest
  double.
- Five plants of its own, all caught. Forming the second weight as one less the first put
  an error 1.5 × 10^14 times over the bound near the end of a domain: the rule the
  contract's bound turns on is load-bearing, by a second measurement.

## What went differently from the order of work

[The development page](development.md#the-order) puts the reference before the
implementation. Here the source was drafted first and the reference written second. The
source was not run until the reference existed, and the reference shares nothing with it:
another route, in another language. The order stands as written for the next batch.

Four of the test's own fixtures were wrong on their first run and the module was right: a
value of `S` worked out by hand, a first derivative asked for at a simple knot of a hat
function, a knot vector with an empty domain, and a run that should have expected a
refusal as too large. Each was a fixture that asserted its premise and failed on it.

## Limits

- **No timing was taken.** The contract's cost section is a count of operations.
- **A batch finds each span twice** where an interior knot is repeated often enough to
  lose a derivative of the order asked for. Otherwise the first look at a parameter is two
  comparisons.
- **The scale sweep moves a whole problem by one factor.** A knot vector far from the
  origin, where differences of knots lose digits before the module sees them, is in the
  family above at one offset and is not swept.
- **Degrees above 6 were not tested.** Nothing in the module depends on the degree but the
  size of its workspace.
- **The sided call at an interior knot does not exist**, as the consumer agreed.
