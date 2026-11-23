# B-spline basis functions

**State: contract for batch 1, accepted by the library's first consumer on 2026-11-22
with the answers recorded at the end. Nothing here is built.** What it waits for is in
[the batch plan](plan.md#what-is-needed-before-batch-1-can-be-built).

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
`(order + 1)(p + 1)` doubles. `spans` is an array of unsigned integers, of another
element type than the two arrays of doubles, so it cannot be either of them.

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
- **There is no call for one side at an interior knot.** It would be the way to ask for
  what the refusal declines, and it is left out until a consumer needs it: the first one
  does not.

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
- **The error is bounded**, as derived in the next section, and the bound is what the
  tests and the review hold the implementation to.

## The error bound

Derived before the code, so that the code is written to meet it. It is to be confirmed
against the exact reference when the module is built; until then it is a derivation, not a
measurement.

Write `u` for the unit roundoff, `2^-53`, and `γ(k)` for `k u / (1 - k u)`. The model is
the usual one for IEEE arithmetic: each of `+ - × ÷` on two doubles returns the exact
result times `1 + δ` with `|δ| ≤ u`, and `k` such factors multiply to `1 + θ` with
`|θ| ≤ γ(k)`. [Provenance](provenance.md#the-register) will cite where that model and
that accumulation are stated.

**Values.** The recurrence is

    N[j, k](t) = a[j, k] N[j, k-1](t) + b[j+1, k] N[j+1, k-1](t)
    a[j, k] = (t - knot[j]) / (knot[j+k] - knot[j])
    b[j, k] = (knot[j+k] - t) / (knot[j+k] - knot[j])

starting from the one function of degree 0 that is 1 on the span. The implementation must
form `b` as written, as a quotient of two differences, and never as `1 - a`.

- Each of `a` and `b` is two subtractions of exact inputs and one division: three
  rounding factors.
- Each product with a value of the degree below adds one, and brings that value's own.
- The sum is of two numbers that are not negative, so it adds one and cannot cancel.

A value of degree `k` therefore carries five more factors than a value of degree `k - 1`,
and the function of degree 0 is exact. So for every basis value written,

    | computed - exact |  ≤  γ(5p) × exact  +  (p + 1)(p + 2) × 2^-1074

a relative bound, because nothing was subtracted that could cancel, and a term for
underflow that matters only for values below the least normal number.

The underflow term, written out. Forming one function of one degree takes two quotients
and two products, and each can underflow, losing at most `2^-1075`; the sum of two numbers
that are not negative loses nothing when it is subnormal. So each function of each degree
gains an error of at most `2 × 2^-1074` of its own. What reaches an output is that error
times a weight. A function of degree `k` passes itself up to the two functions of degree
`k + 1` that it feeds with weights `a` and `b` of one index, which sum to 1; so the weights
with which one function of degree `k` reaches all the outputs sum to 1, and each is at
most 1. An output, though, gathers from all `k + 1` functions of degree `k` that are not
zero, each with a weight of at most 1: `k + 1` in all, and not 1, which would be the sum
the other way. Over the degrees from 1 to `p` that is at most
`2 (2 + 3 + … + (p + 1)) × 2^-1074`, which is `p (p + 3) × 2^-1074`, and the bound above
rounds it up to a form that is easier to remember.

**Derivatives.** A derivative is a difference, so it has no relative bound. The derivative
of order `m` is built from the values of degree `p - m` by `m` steps, one for each degree
`d` from `p - m + 1` to `p`, each of the form

    D[j] = d × ( C[j] / (knot[j+d] - knot[j])  -  C[j+1] / (knot[j+d+1] - knot[j+1]) )

where `C` holds the results of the step before, or the values of degree `p - m` to begin
with, and a term whose knot difference is zero is absent. Each step adds four rounding factors: a
difference of knots, a division, the multiplication by `d`, and the subtraction. With the
`5 (p - m)` of the values it starts from, that is at most `5p` in all, whatever the order.
So, barring underflow,

    | computed - exact |  ≤  γ(5p) × S

where `S` is the size the derivative would have if its terms did not cancel. It is defined
by the same `m` steps with the subtraction made an addition, begun from the exact values:

    S0[j] = N[j, p-m](t)                                   exactly
    Ss[j] = d × ( S(s-1)[j] / (knot[j+d] - knot[j])  +  S(s-1)[j+1] / (knot[j+d+1] - knot[j+1]) )
    S     = Sm[j]                    for d = p - m + s,  s = 1, …, m

with the same terms absent. A test or a reviewer computes `S` in exact rational arithmetic
from the doubles the call was given, and never from the implementation's own
intermediates. Near a clamped end, or where knots crowd, `S` can be orders of magnitude
above the derivative itself; the bound is then correct and weak, and every test that
passes on it reports the ratio of `S` to the exact derivative beside the pass, so that a
weak pass is seen to be one. Underflow is set aside here, and not bounded as it is for the values, because a
division by a small knot difference can magnify what an earlier underflow lost; the tests
will show whether any admitted input reaches that.

**What the bound does not cover**: a parameter that is itself the rounded result of the
caller's arithmetic. The basis is evaluated at the double it is given.

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
- **Identities, to the bound and no tighter.** A correct implementation can return a
  value one rounding above 1, since the last sum of a value near 1 is rounded. So: every
  value is at least 0 and at most `1 + γ(5p)`; the values of one call, summed exactly,
  differ from 1 by at most `γ(5p)` and the underflow terms, since each is within that
  fraction of its own exact value and the exact values sum to 1; and each row of
  derivatives, summed exactly, differs from 0 by at most `γ(5p)` times the sum of its
  `S`.
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

## Settled with the first consumer

Its answers to the five questions this contract was sent with, 2026-11-22.

1. **The sided call is not needed**, and is left out. The consumer's splines are cubic
   with simple interior knots, so every derivative to the second order exists at every
   knot and it never meets the refusal at the orders it asks for. The refusal stays.
2. **One handle for each knot vector is right.** Its knots change only when a control
   point is added or removed, never within a step.
3. **The layout is as proposed**: all values, then all first derivatives, then all second.
   It forms a point and each derivative as a sum over a row.
4. **The highest order it asks for is 2.** The handle's `order` argument covers anything
   later.
5. **Degree 1 as the least is enough.** It uses degree 3 only.

Its use is one case of this contract and not its extent: a cubic on `[0, 1]` with a
uniform clamped knot vector. The tests cover every degree, multiplicity and spacing the
contract admits, and the scale sweep exercises knots far from that interval, which is the
library's generality and not that consumer's need.
