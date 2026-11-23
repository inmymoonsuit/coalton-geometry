# B-spline basis functions

**State: built in batch 1, 2026-11-23**, to the contract the library's first consumer
accepted on 2026-11-22. [The record](batch1.md) has what was measured. Building it
sharpened seven clauses; each is marked *as built* where it stands, and
[the last section](#as-built-what-changed-from-the-accepted-text) lists them. The consumer
accepted all seven on 2026-11-23, having checked the new underflow term by hand, and its
own held-back review of the code found no defect; [the record](batch1.md#the-consumers-review)
has its figures.

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

A knot vector that is not one is a typed error, a `BasisError`, raised before anything is
allocated. It says which rule failed and where; the rules are asked in this order, and the
first that fails answers:

| `BasisError` | The knot vector | It carries |
| --- | --- | --- |
| `DegreeBelowOne` | is asked for degree 0 | the degree |
| `TooFewKnots` | has fewer than `2p + 2` entries | the number given, and the degree |
| `KnotNotFinite` | holds an infinity or a NaN | the index of the first such knot |
| `KnotsDecrease` | has a knot below the one before it | the index of that knot |
| `KnotRepeatedTooOften` | has a knot more than `p + 1` times | the index of the first of the run |
| `EmptyDomain` | has knot `p` equal to knot `n` | those two indices |
| `KnotSpanTooLarge` | has a first and last knot whose difference is not finite | the index of the last knot |

Readers: `degree`, `knot-count`, `control-count`, `highest-order`, `domain-start`,
`domain-end`, and `knots`, a borrowed view of the handle's own copy.

## Evaluating at one parameter

`evaluate!(basis, t, order, out) -> BasisStatus`

Writes into `out`, a caller-owned array of `(order + 1)(p + 1)` doubles, the values and
derivatives at `t` of the `p + 1` basis functions that are not zero on the span holding
`t`: first the `p + 1` values, then the `p + 1` first derivatives, and so on to `order`,
each row in increasing index of basis function. The span is then read with
`latest-span(basis)`: the functions written are those numbered `span - p` to `span`. It is
the span of the latest call that returned `BasisSuccess`; a call that is refused leaves it.

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
be evaluated. The parameters need not be sorted. After a call that no parameter caused to
refuse, `refused-index` is the number of parameters. No parameter at all is a batch like
any other: it succeeds and writes nothing.

## Outcomes

| BasisStatus | Meaning | Written |
| --- | --- | --- |
| BasisSuccess | Every value asked for is written | all |
| BasisOutsideDomain | A parameter is below the domain's start or above its end. It is not clamped. | nothing |
| BasisNonFinite | A parameter is not finite; or a derivative, or one of the terms it is the difference of, is too large to hold | nothing, except that a batch refused because a derivative is too large has written the blocks before `refused-index` |
| BasisDerivativeUndefined | A derivative was asked for at an interior knot where the basis does not have one | nothing |
| BasisBadOrder | The order is above the handle's | nothing |
| BasisBadSize | An array's length is not what the call needs | nothing |

The order and the sizes are asked before any parameter is looked at.

**Too large to hold** is judged on the derivative rows, not on a lower-degree quotient
that will be divided by a wide knot interval later. If the ordinary recurrence overflows,
it is retried with a separate signed binary exponent. Normalization is by powers of two;
the significands follow the same divisions, differences and products, and only the
requested rows are narrowed back to doubles. The basis owns the extra row of exponents.
A single evaluation is computed in the handle's workspace and copied out only when all of
it is finite, so it writes nothing on this refusal either.

*As built.* **An output that is one of the call's own inputs is a typed error**,
`OutputAliased`, raised before anything else is asked: an output that is the handle's
borrowed view of its knots, in either call, and in a batch an output that is the array of
parameters. Nothing is written.

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
- *As built.* **The value is the derivative of order zero, and the rule is the same for
  it.** At an interior knot repeated `p + 1` times the basis itself jumps: `p - m` is
  below zero, no order exists, and a call for values alone is `BasisDerivativeUndefined`.
  The library does not choose a side there either.

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
- *As built.* **Arithmetic is IEEE double with the floating-point traps off**, as the
  pinned compiler's setup leaves them: a quotient that overflows becomes an infinity and is
  found by the check that refuses it. A caller that turns the traps on gets a signal there
  in place of `BasisNonFinite`.

## The error bound

Derived before the code, so that the code was written to meet it, and then confirmed
against the exact reference: every one of 888,461 numbers from 305 knot vectors is within
it, the worst at 0.27 of the bound for a value and 0.22 for a derivative.
[The record](batch1.md) has the measurement. The derivatives' bound was completed by the
building: it had set underflow aside, and the tests reached it.

Write `u` for the unit roundoff, `2^-53`, and `γ(k)` for `k u / (1 - k u)`. The model is
the usual one for IEEE arithmetic: each of `+ - × ÷` on two doubles returns the exact
result times `1 + δ` with `|δ| ≤ u`, and `k` such factors multiply to `1 + θ` with
`|θ| ≤ γ(k)`. [Provenance](provenance.md#the-register) will cite where that model and
that accumulation are stated, and the form of the model with underflow that the two
underflow terms below rest on.

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
So

    | computed - exact |  ≤  γ(5p) × S  +  (1 + γ(5p)) × U

where `S` is the size the derivative would have if its terms did not cancel, and `U` is
what underflow can add. `S` is defined by the same `m` steps with the subtraction made an
addition, begun from the exact values:

    S0[j] = N[j, p-m](t)                                   exactly
    Ss[j] = d × ( S(s-1)[j] / (knot[j+d] - knot[j])  +  S(s-1)[j+1] / (knot[j+d+1] - knot[j+1]) )
    S     = Sm[j]                    for d = p - m + s,  s = 1, …, m

with the same terms absent. A test or a reviewer computes `S` in exact rational arithmetic
from the doubles the call was given, and never from the implementation's own
intermediates. Near a clamped end, or where knots crowd, `S` can be orders of magnitude
above the derivative itself; the bound is then correct and weak, and the tests report the
largest ratio of `S` to the exact derivative that they met, so that a weak pass is seen to
be one.

*As built.* **`U`, the underflow term.** The accepted text set underflow aside for the
derivatives, since a division by a small knot difference can magnify what an earlier
underflow lost, and left it to the tests to show whether an admitted input reaches that.
One does: a parameter within a subnormal distance of a knot. So the term is derived, and
it is carried through the same steps as `S`:

    U0[j] = (k + 1)(k + 2) × 2^-1074                        for k = p - m
    Us[j] = d × ( U(s-1)[j] / (knot[j+d] - knot[j])  +  U(s-1)[j+1] / (knot[j+d+1] - knot[j+1])  +  2^-1074 )
    U     = Um[j]

`U0` is the underflow term of the values the derivative starts from. Each step divides,
which magnifies what is already lost exactly as it magnifies everything else, and forms
two quotients that can each underflow by `2^-1075`; a difference of doubles that is
subnormal is exact, and so is its product with a small whole number. The factor
`1 + γ(5p)` is the rounding of the later steps acting on what was lost in the earlier.
Where no knot difference is far below 1 and the degree is small, `U` is a few thousand
times `2^-1074` and is nothing; where knots are themselves near the bottom of the range it
is what the bound consists of.

**What the bound does not cover**: a parameter that is itself the rounded result of the
caller's arithmetic. The basis is evaluated at the double it is given.

## The four questions, and the fifth

1. **An intermediate out of range.** Differences of doubles do not underflow. A difference
   of knots across the whole vector is checked finite when the handle is made, so no later
   difference can overflow. Quotients lie in `[0, 1]`. Only a derivative's division by a
   small knot difference or its subsequent scaling can leave the range. A lower-degree
   intermediate can overflow even though a requested row fits; the retry above handles it.
2. **Two arguments one array.** `parameters` and `out` are both arrays of doubles. A block
   for each parameter is longer than one parameter, so they have one length only when
   there is no parameter; they are refused if they are one array. *As built:* the handle's
   borrowed view of its knots is also an array of doubles a caller holds, and an output
   that is it would overwrite the knots; that is refused too.
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
  `S`, and `1 + γ(5p)` times the sum of its `U`.
- **The scale sweep**: knots and parameters multiplied by a power of two leave the spans
  and values exactly as they were, and divide the derivative of order `k` by that power
  `k` times, across the range.
- **Knot vectors that try it**: clamped and unclamped, uniform and wildly uneven, every
  permitted multiplicity inside and at the ends, parameters at knots, just beside knots,
  and at both ends of the domain.
- **Allocation**: nothing in a warmed call, single or batched, at both safety policies.

## Cost

A span is found by bisection, in a number of steps logarithmic in the number of knots. The
values at one parameter take a number of operations quadratic in the degree. *As built:*
the derivative of order `m` takes `m` steps over at most `p + 1` entries, so the
derivatives to order `k` add an amount proportional to `k²` times the degree, not to `k`
times it as the accepted text said. Storage is the copy of the knots and a workspace
quadratic in the degree.

A batch looks at each parameter twice, since all are checked before any is written. The
first look is two comparisons where no interior knot is repeated often enough to lose a
derivative of the order asked for, which the handle works out once when it is made; only
otherwise does it find the span twice. No timing has been taken.

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

## As built: what changed from the accepted text

Seven clauses, each marked where it stands, each accepted by the first consumer on
2026-11-23. None changes what its use gets: a cubic with simple interior knots, to the
second order, on knots of ordinary size.

1. **The derivatives' bound has an underflow term, `U`.** The accepted text set underflow
   aside; an admitted input reaches it, so it is derived and tested.
2. **`BasisNonFinite` covers a term too large to hold**, not only a derivative that is,
   since the derivative is a difference of such terms. A single evaluation writes nothing
   on it; the accepted text allowed it to.
3. **A call for values at an interior knot repeated `p + 1` times is refused**, as
   `BasisDerivativeUndefined`: the accepted rule, read for order zero.
4. **An output that is the handle's own knots is a typed error**, `OutputAliased`, as is a
   batch's output that is its parameters, which the accepted text called a refusal without
   saying of which kind.
5. **The derivatives cost `k²` times the degree**, not `k` times.
6. **Arithmetic assumes the floating-point traps are off.**
7. **Names**: the typed errors of the table above, `knots` for the borrowed view, and what
   `latest-span` and `refused-index` hold after a call that was refused or was not.
