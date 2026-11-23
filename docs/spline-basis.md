# B-spline basis functions

**State: draft contract for batch 1, proposed 2026-11-22. Nothing here is built.** It is
written to be read and corrected by the library's first consumer before any code, and its
open questions are at the end. Names and layouts are proposals until then.

Package `coalton-geometry/spline/basis`. Terms and conventions are those of
[the conventions page](../CONTEXT.md#splines).

## What it is for

A B-spline curve of degree `p` is a combination of its control points, weighted at each
parameter by `p + 1` basis functions that are not zero there. A solver that holds a point
on such a curve, or makes something tangent to it, needs those weights and their
derivatives with respect to the parameter: the weights give the point and its derivative
with respect to every control point, and the derivatives give the tangent and the
curvature. This module computes exactly that and nothing else. Control points, rational
weights and curves are the next batch.

## The handle

`make-basis(degree, knots, order) -> Basis`

Made once for a knot vector. It checks the knots, copies them, and allocates every
workspace a later call uses, so that **no later call allocates**.

- `degree`: `p`, at least 1.
- `knots`: a non-decreasing array of finite doubles, at least `2p + 2` of them. The number
  of control points it implies is its length less `p + 1`.
- `order`: the highest derivative any later call may ask for. Zero for values only.

A knot vector that is not one is a typed error, raised before anything is allocated, that
says which rule failed:

| Refusal | The knot vector |
| --- | --- |
| too few knots | has fewer than `2p + 2` entries |
| not finite | holds an infinity or a NaN |
| decreasing | has a knot below the one before it |
| repeated too often | has a knot more than `p + 1` times |
| empty domain | has knot `p` equal to knot `n` |
| span too large | has a first and last knot whose difference is not finite |

Readers: `degree`, `knot-count`, `control-count`, `highest-order`, `domain-start`,
`domain-end`, and a borrowed view of the knots.

## Evaluating at one parameter

`evaluate!(basis, t, order, out) -> BasisStatus`

Writes into `out`, a caller-owned array of `(order + 1)(p + 1)` doubles, the values and
derivatives at `t` of the `p + 1` basis functions that are not zero on the span holding
`t`: first the `p + 1` values, then the `p + 1` first derivatives, and so on to `order`,
each row in increasing index of basis function. The span is then read with
`latest-span(basis)`: the functions written are those numbered `span - p` to `span`.

- An order above the degree is not an error. Those derivatives are zero and are written
  as zero.
- An order above the handle's own is refused.

## Evaluating at many parameters

`evaluate-batch!(basis, parameters, order, spans, out) -> BasisStatus`

For `parameters`, a caller-owned array of `count` doubles: writes `count` spans into
`spans`, and into `out` the block above for each parameter in turn, `count` blocks of
`(order + 1)(p + 1)` doubles.

**Every parameter is checked before anything is written.** On a refusal nothing has been
written, and `refused-index(basis)` is the position of the first parameter that could not
be evaluated. The parameters need not be sorted.

## Outcomes

| BasisStatus | Meaning | Written |
| --- | --- | --- |
| BasisSuccess | Every value asked for is written | all |
| BasisOutsideDomain | A parameter is below the domain's start or above its end. It is not clamped. | nothing |
| BasisNonFinite | A parameter is not finite, or a derivative's value is not a finite double | nothing, or unspecified in the second case |
| BasisDerivativeUndefined | A derivative was asked for at an interior knot where the basis does not have one | nothing |
| BasisBadOrder | The order is above the handle's | nothing |
| BasisBadSize | An array's length is not what the call needs | nothing |

## Where a derivative does not exist

A basis function of degree `p` has `p - m` continuous derivatives at a knot repeated `m`
times, and no more: the next one jumps.

- **Inside a span every derivative exists.**
- **At an interior knot of multiplicity `m`, derivatives of order up to `p - m` exist and
  are returned. A higher one is `BasisDerivativeUndefined`.** It has a value from the left
  and another from the right, and the library does not choose.
- **At the two ends of the domain the derivative is the one from inside the domain.** That
  is the only derivative a curve has at its end, and it is what is meant by an end
  derivative. This is a convention of this contract.
- A caller who wants one side at an interior knot says which, with
  `evaluate-from!(basis, side, t, order, out)`, `side` being `FromBelow` or `FromAbove`.

## Arithmetic

- **The values are computed by the recurrence that builds each degree from the one below
  it**, using only differences of knots, differences between the parameter and a knot,
  quotients of those, and sums of products of quantities that are not negative. Nothing is
  subtracted that could cancel.
- **A term whose knot difference is zero is not computed.** A basis function over an empty
  span is zero by definition, and the recurrence is arranged so that no zero divides
  anything, not by testing a quotient after the fact.
- **The derivatives come from the same table**, by the differences the recurrence implies,
  each divided by a knot difference. Where knots nearly coincide a derivative can be too
  large to hold although every input is ordinary; that is `BasisNonFinite`.
- **An error bound will be stated and tested**, as a multiple of the unit roundoff that
  depends only on the degree and the order. This draft does not state one, because it has
  not been derived yet.

## The four questions, and the fifth

1. **An intermediate out of range.** Differences of doubles do not underflow. A difference
   of knots across the whole vector is checked finite when the handle is made, so no later
   difference can overflow. Quotients lie in `[0, 1]`. Only a derivative's division by a
   small knot difference can leave the range, and its result is then itself out of range
   and refused.
2. **Two arguments one array.** `parameters` and `out` are both arrays of doubles. They
   can have one length only by coincidence, and are refused if they are one array.
3. **Work for a step not taken.** No derivative above the order asked for is computed, and
   a batch is checked whole before any of it is evaluated.
4. **Anything written or allocated before a refusal.** Nothing is allocated after the
   handle is made, and every check precedes the first write.
5. **Degenerate input.** Repeated knots are ordinary and handled as above. A parameter
   equal to a knot belongs to the span on its right, and to the last span at the domain's
   end.

## How it will be checked

- **Against exact rational arithmetic, by another route.** The polynomial `(y - t)^p` is
  the combination of the basis functions at `t` with coefficients that are products of
  `y` less a knot. Evaluated at `p + 1` values of `y` that gives a linear system whose one
  solution is the exact basis values, with no recurrence in it; differentiating the same
  identity in `t` gives the derivatives the same way. The implementation is compared with
  that solution, computed in rationals from the doubles it was given.
- **Identities**: the values sum to one, every derivative row sums to zero, and every value
  is in `[0, 1]`.
- **The scale sweep**: knots and parameters multiplied by a power of two leave the spans
  and values exactly as they were, and divide the derivative of order `k` by that power
  `k` times, across the range.
- **Knot vectors that try it**: clamped and unclamped, uniform and wildly uneven, every
  permitted multiplicity inside and at the ends, parameters at knots, just beside knots,
  and at both ends of the domain.
- **Allocation**: nothing in a warmed call, single or batched, at both safety policies.

## Cost

A span is found by bisection, in a number of steps logarithmic in the number of knots. The
values at one parameter take a number of operations quadratic in the degree; the
derivatives to order `k` add an amount proportional to `k` times the degree. Storage is
the copy of the knots and a workspace quadratic in the degree.

## What it does not do

- Control points, rational weights, or a curve: [batch 2](plan.md#the-batches).
- Knot insertion, degree elevation, or any change to a knot vector.
- Periodic splines as such. A knot vector that happens to be uniform is accepted like any
  other; nothing wraps.

## Open questions for the consumer

1. **Is the sided call needed?** A solver's iterate lands exactly on a knot rarely, but a
   starting value often does. Is a refusal at an interior knot enough, with the solver
   stepping off it, or does it want `evaluate-from!`?
2. **Is one handle for each knot vector right?** It copies and checks the knots once. A
   consumer that changes knots at every step would rather pass them to each call and pay
   the check each time.
3. **The layout of `out`**: all values, then all first derivatives, as proposed, or for
   each basis function its value and its derivatives together?
4. **The highest order ever wanted.** Two covers tangency and curvature. Is a third
   derivative ever asked for?
5. **Is degree 1 enough as the least**, or is a degree-0 basis ever wanted for uniformity?
