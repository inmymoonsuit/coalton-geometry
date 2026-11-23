# A B-spline curve and its derivatives

**State: built in batch 2, 2026-11-23**, to the contract the library's first consumer
signed as written the same day. [The record](batch2.md) has what was measured. Building it
changed no clause; three things the draft left unsaid are marked *as built* where they
stand.

Package `coalton-geometry/spline/curve`. It stands on
[the basis module](spline-basis.md), whose terms and refusals it keeps, and on
[the conventions](../CONTEXT.md#splines).

## What it is for

A point of a B-spline curve is the sum of its control points, each weighted by a basis
function; a derivative with respect to the parameter is the same sum with the basis
function's derivative. A solver holding a point on a curve needs the point, the tangent
and the curvature vector, and the weights themselves, which are the derivative of the
point with respect to each control point. One call gives all four.

This batch is the curve that is not rational. A rational curve is not on the first
consumer's path and no text to hand treats one; it is left until both change.

## What a curve is

Not a handle. A curve is a [basis](spline-basis.md#the-handle), which holds the degree
and the knots and is made once, and an array of control points, which the caller owns and
may change between calls: in a solver the control points are unknowns and the knots are
not.

- `controls`: the control points, as [the conventions](../CONTEXT.md#space) hold points:
  a point after a point, `dimension` coordinates each. Its length is `dimension` times the
  basis's `control-count`, exactly.
- `dimension`: at least 1. The plane is 2 and space is 3; nothing in the module depends
  on which.

## Evaluating at one parameter

`evaluate!(basis, controls, dimension, t, order, rows, out) -> BasisStatus`

- Writes into `rows`, a caller-owned array of `(order + 1)(p + 1)` doubles, exactly what
  [the basis module's `evaluate!`](spline-basis.md#evaluating-at-one-parameter) writes for
  `t` and `order`. Row `m` of it is the derivative of the curve's `m`-th derivative with
  respect to each control point of the span: the control point numbered `span - p + r`
  moves that derivative by the entry `r` of the row, in every coordinate alike.
- Writes into `out`, a caller-owned array of `(order + 1) × dimension` doubles: the point,
  then the first derivative with respect to the parameter, and so on to `order`.
- The span is read with the basis's `latest-span`, as after the basis module's own call.

An order above the degree is zero and is written as zero.

## Evaluating at many parameters

`evaluate-batch!(basis, controls, dimension, parameters, order, spans, rows, out) -> BasisStatus`

For `parameters`, an array of `count` doubles: `count` spans into `spans`, `count` blocks
of `(order + 1)(p + 1)` into `rows`, and `count` blocks of `(order + 1) × dimension` into
`out`, each as the single call lays one out. The basis's `refused-index` is the position
of the first parameter that could not be evaluated, as after the basis module's own batch.
A batch is its single calls, bit for bit.

*As built.* **`refused-index` is meaningful only after a refusal that the basis's own batch
made**: `BasisOutsideDomain`, `BasisDerivativeUndefined`, or `BasisNonFinite` for a
parameter or a basis derivative. It is then the position of the first such parameter. After
a success, and after a refusal for a control point or a result, which is no parameter's
doing, it is the number of parameters. **After a refusal the curve module decides for
itself, `BasisBadOrder` or `BasisBadSize`, it is unspecified and must not be read**: the
module has no handle to keep a position in, and the value there belongs to an earlier
call.

## Outcomes

The statuses are the basis module's own, since every outcome but one is the basis's.

| BasisStatus | Meaning here | `rows` | `out` |
| --- | --- | --- | --- |
| BasisSuccess | Everything asked for is written | written | written |
| BasisOutsideDomain, BasisDerivativeUndefined | As in the basis module | untouched | untouched |
| BasisBadOrder | The order is above the basis's | untouched | untouched |
| BasisBadSize | An array's length is not what the call needs, or the dimension is zero | untouched | untouched |
| BasisNonFinite | A parameter is not finite, or a basis derivative is too large to hold | as the basis module leaves it | untouched |
| BasisNonFinite | A control point of a span that is used has a coordinate that is not finite, or a coordinate of a result is too large to hold | written | untouched |

**`out` is written only on success.** Every sum is formed once to see that it is a finite
number, and written on a second pass; the sums are the cheapest part of a call and are
formed twice for that guarantee. `rows` holds true basis values whenever it is written.

*As built.* **After a single call refused for a control point or a result, the basis's
`latest-span` is that parameter's span**: the basis's own call succeeded and wrote `rows`.

*As built.* **A control point that is not finite is found through the sums, not looked for
apart from them.** Every sum takes every control point of the span, and nothing times a
number that is not finite is finite, so the check of the sums is the check of the control
points. A separate check was written first; it could change no outcome, and was removed.

An output that is one of the call's inputs is the basis module's typed error,
`OutputAliased`, raised before anything else is asked: `rows` or `out` that is `controls`,
the parameters, the basis's borrowed view of its knots, or each other.

## Where a derivative does not exist

The basis module's rule, unchanged: at an interior knot of multiplicity `m`, orders up to
`p - m` are returned and a higher one is `BasisDerivativeUndefined`. A curve can be
smoother at a knot than its basis is, when its control points happen to make it so. The
module does not look: it would be deciding from the control points' values, which change.

## Arithmetic

- Each coordinate of each result is the sum, in increasing number of control point, of
  `p + 1` products of a basis entry and a coordinate. Nothing else is computed.
- The basis entries are the basis module's, to its bound.
- IEEE double with the floating-point traps off, as in the basis module.

## The error bound

Derived before the code, checked by the consumer, and then confirmed against the exact
reference: every one of 58,182 numbers from 53 knot vectors is within it, the worst at
0.26 of the bound, and 1,601 more from control points so small that the underflow terms
are what admits them. [The record](batch2.md) has the measurement.

A basis entry carries at most `5p` rounding factors. Its product with a coordinate adds
one, and summing `p + 1` terms adds at most `p`. So for each coordinate of the point,
writing `P[j]` for that coordinate of control point `j` and summing over the `p + 1`
control points of the span,

    | computed - exact |  ≤  γ(6p + 1) × Σ N[j](t) |P[j]|  +  (1 + γ(6p + 1)) × ( V × Σ |P[j]|  +  (p + 1) × 2^-1075 )

For a derivative of order `m` the same holds with the basis module's `S[j]` in place of
`N[j](t)` and its `U[j]` in place of `V`:

    | computed - exact |  ≤  γ(6p + 1) × Σ S[j] |P[j]|  +  (1 + γ(6p + 1)) × ( Σ U[j] |P[j]|  +  (p + 1) × 2^-1075 )

**The underflow terms, each named.**

- `V`, or `U[j]`, times `|P[j]|`: a basis entry can itself be off by what underflow lost
  in forming it, which is `V = (p + 1)(p + 2) × 2^-1074` for a value and
  [the basis module's `U`](spline-basis.md#the-error-bound) for a derivative. The product
  carries that loss multiplied by the coordinate.
- `(p + 1) × 2^-1075`: each of the `p + 1` products of an entry and a coordinate can
  underflow, and one that does is off by at most half the least positive number.
- Nothing for the sums: a sum of doubles that is below the normal range is exact.
- The factor `1 + γ(6p + 1)` is the rounding of the later operations acting on what an
  earlier one lost.

**The bound is relative to the size of the control points and not to the point.** The
weights are not negative and sum to one, so the first sum is at most the largest `|P[j]|`
of the span. Where control points of opposite sign cancel, or a curve lies far from the
origin, the point is small beside its control points and the error is not small beside
the point. That is the conditioning of the sum and no arrangement of it removes it; a
caller that wants more keeps its control points near its origin.

## The four questions, and the fifth

1. **An intermediate out of range.** A product or a sum can overflow where a control
   point is very large. Every result is checked finite before any is written.
2. **Two arguments one array.** `controls`, `parameters`, `rows` and `out` are all arrays
   of doubles, and several pairs can have one length: `rows` and `out` whenever the
   dimension is the degree and one, which a line in the plane is. Every pair with an
   output in it is refused. `controls` and `parameters` are both only read.
3. **Work for a step not taken.** Only the `p + 1` control points of a span are read, and
   only they are checked: a control point elsewhere that is not finite does not refuse a
   call that does not use it.
4. **Anything written or allocated before a refusal.** Nothing is allocated at all: the
   module has no handle of its own. `out` is written only on success, and `rows` only once
   every parameter is admitted.
5. **Degenerate input.** Control points that coincide, or all lie on a line, are ordinary:
   the curve is then a point or a segment and its derivatives are what they are, zero
   among them. Nothing is refused for it. Whether a zero tangent matters is the caller's
   question, and the search of the next batch will have to answer it for itself.

## How it will be checked

- **Against exact rational arithmetic, by another route.** The point by repeated convex
  combination of control points, which forms no basis function; each derivative as the
  curve one degree lower on the scaled differences of the control points, evaluated the
  same way. [The reference texts](references.md#batch-2-splinecurve-built) say where each is;
  the first is placed by its title and is read when the batch is built. Compared to the bound above, with the sums of
  the bound computed exactly.
- **Identities.** The point lies in the box of the span's control points, widened by the
  bound. A curve whose control points are all one point is that point with every
  derivative zero. Control points on a line at the abscissae the knots imply reproduce the
  line. Moving every control point by one vector moves the point by it and no derivative,
  to the bound.
- **`rows` is the basis module's output**, bit for bit.
- **Two scale sweeps**: the control points multiplied by a power of two, which multiplies
  the point and every derivative by it; and the knots and parameters multiplied, which
  leaves the point and divides the derivative of order `m` by that power `m` times.
- **The aliasing roster**, for both calls, with every pair that can be one array.
- **Allocation**: nothing, at both safety policies.

## Cost

The basis module's cost, and `2 (order + 1) × dimension × (p + 1)` multiplications and
additions. A batch looks at its parameters as the basis module's batch does.

## What it does not do

- Rational curves.
- Derivatives with respect to control points as a call of their own: they are `rows`.
- Derivatives with respect to a knot.
- Anything that changes a curve: inserting a knot, raising a degree, splitting.
- The nearest parameter to a point: [batch 3](plan.md#the-batches).

## Settled with the first consumer

Its answers of 2026-11-23, before the draft.

1. **Control points are interleaved coordinates in one array**, a point after a point.
2. **The plane only, for its first use**; space later. The dimension is an argument.
3. **The basis rows are the derivatives with respect to the control points.** No call for
   them is wanted.
4. **Rational weights are not in its first use.** Every spline it holds is a cubic that is
   not rational.

Its answers to the draft's five questions, the same day, with its signature.

5. **One call writes both `rows` and `out`.** It needs both, and one basis evaluation is
   right.
6. **The basis module's status type is reused.**
7. **`out` is written only on success.** Forming each sum twice is nothing beside a
   refusal that writes nothing holding everywhere.
8. **Only the control points of the span are checked.** The others cannot change the
   result.
9. **No handle here.** A workspace for the search belongs to the next batch.

It also checked the count of the bound, and asked that the underflow terms be written out,
which they now are.

It accepted the three points marked *as built* the same day, and asked for the wording of
the one about `refused-index`, which is as it stands above.
