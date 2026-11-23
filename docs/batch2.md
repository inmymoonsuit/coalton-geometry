# Batch 2: B-spline curves

State: completed 2026-11-23; both complete checks pass at safety 1 and safety 0 on
Windows x86-64, SBCL 2.6.10 and the pinned Coalton compiler. The library's first consumer
signed the contract as written before any code, and its own review of the code, with tests
this library's author did not see, found no defect: [below](#the-consumers-review).

## What was built

Package `coalton-geometry/spline/curve`, in [`src/spline/curve.ct`](../src/spline/curve.ct),
to [its contract](spline-curve.md): `evaluate!` for one parameter and `evaluate-batch!`
for many. Each writes the basis rows of the parameter, which are the derivatives of the
curve with respect to the control points of the span, and the point of the curve with its
derivatives with respect to the parameter, in any dimension. The module has no handle and
allocates nothing: a curve is [a basis](spline-basis.md) and an array of control points
the caller owns.

It calls the basis module through its public interface and adds one thing, the sums. Its
tests are [`tests/spline-curve.lisp`](../tests/spline-curve.lisp), with compiled callers
in a file and a package of their own; it has its entries in both rosters and
[a roster of planted defects](../tests/plants/batch2.py). The basis module is unchanged.

## Where the method was read

[The register](provenance.md#the-register) has the two entries.

| What | Where |
| --- | --- |
| A curve as the combination of its control points by the basis | Prautzsch, Boehm and Paluszny, 5.4, p. 63 |
| The point by repeated convex combination, for the exact reference | The same, 5.4, p. 64 |
| The derivative as the curve one degree lower on scaled differences, for the exact reference | The same, 5.6, p. 67, equation (1) |

All mathematics. The module's route and the reference's are different ones: the module
sums products of basis entries and coordinates; the reference forms no basis function.

## What was measured

### Against the exact reference

| | |
| --- | --- |
| Knot vectors | 53, of degrees 1 to 5, in one, two and three dimensions |
| Parameters | 1,748 |
| Evaluations compared | 8,257 |
| Numbers compared | 58,182 |
| Worst error | 0.263 of its bound |

The knot vectors are of the kinds the basis module's tests use, short of its extremes;
the control points are of mixed sign, of sizes from 2^-20 to 2^20, and not round. Each is
tried at every parameter the basis tests try and at every order from 0 to one above the
degree. In every evaluation the rows written are compared, bit for bit, with the basis
module's own output.

### Where the underflow terms are what is checked

No number of that family needed the bound's underflow terms, so the family did not test
them. Five more knot vectors were given control points 2^1050 times smaller, where a
weight times a coordinate is below the normal range: 297 evaluations, 1,601 numbers, all
within the bound, 784 of them only by its underflow terms.

### Refusals

Every status, with `rows` and `out` checked to be untouched where the contract says so,
and `rows` checked to hold the basis module's values where it says they are written. A
control point of the span that is not finite, at three positions, and a result too large
from control points that are finite: refused with `out` untouched. A control point that is
not finite and is not of the span: no refusal, and the same result bit for bit. Each pair
of arrays with an output in it, as one array: the typed error, and nothing written. A
batch is its single calls bit for bit, in the spans, the rows and the result.

### Allocation

Counted through loops compiled in another file and another package, at both safety
policies: 0 bytes for a round of six `evaluate!` calls to the second order, and 0 for an
`evaluate-batch!` of six parameters.

### The scale sweep

| Entry | Across the sweep |
| --- | --- |
| The control points scaled | exact from 2^-1000 to 2^1000; within a few last places at 2^-1020, where products are below the normal range and their sum is not; refused at 2^1020, where a second derivative is too large to hold |
| The knots and parameters scaled | refused from 2^-1020 to 2^-510, exact from 2^-400 to 2^400, lost from 2^510: the basis module's own pattern, since the point does not move and a derivative moves as the basis's does |

No run is a `:limit`.

### The aliasing roster

Both calls are members. For one evaluation, a segment of the plane to the first order
makes all three arrays four entries long, and each of the three pairs is refused. For a
batch, the control points and the parameters are both only read and are accepted as one
array; the rows and the result are refused as one.

## What the planted defects showed

Twelve edits to the module's source, each applied alone and each caught:
`python tools/plants.py tests/plants/batch2.py`.

| Planted | Noticed first by |
| --- | --- |
| The coordinates of a sum taken one apart, not a dimension apart | the refusals |
| The first control point of the span taken one too high | the refusals |
| A second derivative written from the row of the first | the family against the reference |
| A result that is not finite written as it is | the refusals |
| A batch's results checked only as far as its first parameter | the batch tests |
| Orders above the degree left as the caller's array had them | the family against the reference |
| The result of one evaluation allowed to be the basis's own knots | the refusals |
| The result of a batch allowed to be its parameters | the batch tests |
| The rows and the result of a batch allowed to be one array | the batch tests |
| An array of control points accepted when it is too long | the refusals |
| No dimension accepted | the refusals |
| The results of a batch placed a block of rows apart | the batch tests |

The refusal tests compare a successful result with a second one, so they notice a wrong
sum before the family does; that is why two arithmetic plants are caught there first.

## What the building found

1. **A check that could change no outcome.** The source as first written looked at the
   control points of the span for a coordinate that is not finite before forming any sum.
   Writing a plant for it showed there was nothing for a test to catch: every sum takes
   every control point of the span, and a number that is not finite makes the sum not
   finite, so the check of the sums already refuses every such call. The separate check
   was removed, before the plants were run.
2. **The first family did not reach the underflow terms.** The count of numbers that
   needed them was zero, which the test printed. Fixtures that do reach them were added,
   with their premise asserted.
3. **Where a refused batch's position can be read** was unsaid in the draft and is now in
   the contract: the basis reports one only where its own batch ran.

Nothing in the signed contract was changed.

## The consumer's review

Held back from the author and run on the commit as pushed, 2026-11-23. Its figures, as it
reported them:

- 16,321 checks against exact rational arithmetic, none failed, and no compiler warning.
- Plane cubics at the scale of its own use; 80 random cases of degrees 1 to 5 and
  dimensions 1 to 3, with control points from 2^-100 to 2^100 and far from the origin;
  control points from 2^-1060 to 2^-1074, where products underflow; a batch against its
  single calls bit for bit; control points scaled from 2^-1000 to 2^1000; every refusal.
- Every coordinate held to the contract's bound, with the sums of the bound computed from
  the basis contract's formulas, and the rows compared bit for bit with the basis module's
  own output.
- Its worst errors, as fractions of the bound: 0.94 for a point, 0.85, 0.70 and 0.16 for
  the first three derivatives. **The bound is nearly tight for the point**, as a bound
  taken term by term on a sum is, and this record's own 0.26 did not show that: the
  consumer's control points far from the origin did.
- Four plants of its own, all caught.

## The order of work

The reference was written and its closed-form cases chosen before the module's source,
as [the development page](development.md#the-order) asks and as batch 1 did not. The
module passed on its first run. Two fixtures of the test did not: knot vectors with an
empty domain, each failing on the premise it asserted.

## Limits

- **No timing was taken.**
- **The bound is relative to the size of the control points**, as the contract says: a
  curve far from the origin has a point small beside its control points.
- **Dimensions above 3 and degrees above 5 were not tested.** Nothing in the module
  depends on either but the length of its loops.
- **Rational curves are not here.**
