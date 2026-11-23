# The nearest parameter of a B-spline curve to a point

**State: contract for batch 3. The library's first consumer accepted its shape on
2026-11-23 and answered its questions; the bounds it asked to have derived before any code
are derived below. Nothing here is built.** Deriving them changed the wording of two
promises, which is said where they stand.

Package `coalton-geometry/spline/nearest`. It stands on [the curve module](spline-curve.md)
and [the basis module](spline-basis.md), and on [the conventions](../CONTEXT.md#curves):
a nearest point is a foot, or an end of the domain.

## What it is for

A solver that holds a point on a curve asks, at every step, which parameter of the curve
is nearest to the point. It asks for many points against one curve, and the curve's
control points have moved since the last step. The answer must be the nearest of the
whole curve and not the one continued from the step before; and where the curve offers
two answers the solver must be told, not given one.

## What is asked, exactly

For a curve `C` on the domain `[a, b]` and a point `X`, the parameter `t` at which
`|C(t) - X|` is least. A least distance is reached either

- at an **interior foot**, where `(C(t) - X) · C'(t) = 0`, or
- at an **end of the domain**, `a` or `b`, where the curve stops before a foot is reached.

## What a search is

`make-search(basis, dimension, depth) -> Search`

A handle for one basis and one dimension. It allocates every workspace a later call uses,
and no later call allocates. `depth` bounds the work spent on one point: how many times a
span of the curve may be halved, and halved again, while looking for it.

The curve must be smooth enough to search. A typed error is raised, before anything is
allocated, for:

- a degree below 2;
- a basis made for an order below 2;
- an interior knot repeated more than `p - 1` times, where the tangent can turn or the
  curve can break;
- a dimension of zero, or above 4096, the most the bounds below are derived for.

The control points are not held: they are an argument of every call.

## Searching

`nearest!(search, controls, points, hints, step, tie, feet, reports, measures) -> SearchStatus`

- `controls`: the control points, as [the curve module](spline-curve.md#what-a-curve-is)
  takes them.
- `points`: `count` points, `dimension` coordinates each.
- `hints`: either no entry, or `count` parameters, one for each point: a guess, such as
  the answer of the step before. **A hint can only save work. It never changes the
  answer**, and a hint outside the domain or far from the answer costs nothing but its own
  evaluation.
- `step`: a tolerance in the units of the parameter, at least zero. A foot is returned
  inside an interval no wider than this that holds it, or as narrow as the arithmetic can
  make it where that is wider.
- `tie`: a tolerance in the units of length, at least zero, for reporting a second answer.

Written, for each point in turn:

- `feet`, `count` doubles: the parameter. At an end of the domain it is that end exactly,
  the knot's own value.
- `reports`, `count` unsigned integers: what kind of answer it is. See below.
- `measures`, `4 × count` doubles: the distance `|C(t) - X|`; the residual
  `(C(t) - X) · C'(t)` as computed at the returned parameter; a bound on how far that
  computed residual can be from the exact one at that parameter; and the speed `|C'(t)|`
  there, by which a caller can decline a foot where the curve nearly stops.

### The report for a point

One code for each point.

| Report | Meaning | Parameter and measures |
| --- | --- | --- |
| `foot` | The nearest point of the curve, at a parameter strictly inside the domain | written |
| `start`, `end` | The nearest point of the curve is at that end of the domain | written; the parameter is the end exactly |
| `tied` | A second least point of the distance, apart from the one returned, is within `tie` of being as near, or could not be shown not to be | written, for the nearer of those found |
| `unresolved` | The work allowed by `depth` ran out before the curve could be shown to hold one answer. A curve that is a single point, or a point at the centre of an arc, ends here | not a number, in every entry: no parameter is returned |

**`start` and `end` are decided by the parameter returned and by nothing else.** The
report is `foot` exactly when the returned parameter is strictly between the ends of the
domain. A foot that coincides with an end to the last bit is reported as that end.

`tied` and `unresolved` are reports and not refusals: the other points of the batch are
answered.

### What is promised

Each of these is proved in [the derivation below](#the-bounds-derived), with the
arithmetic's own error inside it.

1. **A foot is a foot.** For a report of `foot`, the returned parameter lies in an
   interval of the curve on which the squared distance is convex, so that the interval
   holds one least point and no other; and either it lies between two parameters no more
   than `step` apart at which the residual is shown to have opposite signs, or the
   residual at it is zero to within its bound, which is as narrow as the arithmetic can
   make it.
2. **Nearest means of the whole curve.** For a report of `foot`, `start` or `end`, every
   other least point of the distance, every other foot that is a local minimum and the
   other end, is farther than the returned distance by more than `tie`. Every part of the
   curve that was set aside was set aside by a bound that holds for all of it, not by
   sampling it.
3. **A second answer is never hidden.** If a part of the curve apart from the one
   returned could hold a least point within `tie` of as near, and the bounds cannot
   exclude it, the report is `tied` or `unresolved`. The report errs toward saying so.
4. **A hint changes none of the three.** They hold whatever hints are given.

*Changed by the derivation.* The draft's second promise spoke of every point of the curve
outside the answer's interval, which is false of any curve: the points beside a foot are
barely farther than the foot. It is a promise about other least points. The first now
says what is certain where the residual is too small to have a sign.

## How it searches

In outline; the next section has the bounds.

- **Each span is taken in turn, and an interval of it is looked at through its middle.**
  The curve is evaluated there to the second order.
- **Set aside by distance.** A curve segment lies in the convex hull of the control points
  of its span, and its derivative curve in the hull of its own. So the speed over a span
  is at most the largest of the derivative's control points there, and the distance at the
  middle of an interval, less that speed times half its width, bounds the distance to all
  of it from below. An interval whose bound is above the least distance found so far by
  more than `tie` holds no answer and no tie.
- **Set aside as rising or falling.** Where the residual is shown to keep one sign over an
  interval, the distance only rises or only falls across it and no least point lies in it,
  unless it is the end of the domain that the distance falls toward.
- **Convex, then one least point.** Where the squared distance is shown convex over an
  interval it holds one least point. The residuals at its two ends say where: at an end of
  the interval, or between, where Newton's method finds it inside a bracket that is
  halved whenever a step would leave it.
- **Otherwise halved**, until `depth` is spent.
- **The least of what was found is the answer.** Two candidates in intervals that touch,
  each convex, are one least point and not two.

## The bounds, derived

Everything here is in exact arithmetic unless it is called *computed*. `D` is the
dimension, `u` is `2^-53`, and `γ(k)` is as in [the basis contract](spline-basis.md#the-error-bound).

**One device for every comparison.** Each test below is arranged as one computed number
against a sum of terms that are not negative, and the sum is multiplied by `1 + 2^-40`
before the comparison. Forming such a sum in floating point from fewer than a thousand
operations is off by less than `2^-43` of it, so the comparison can only err toward
keeping an interval, never toward setting one aside.

### What is known of a whole span

For a span, with `P[j]` its control points:

- `Q[j] = p (P[j] - P[j-1]) / (knot[j+p] - knot[j])`, the `p` control points of the
  derivative. The derivative at any parameter of the span is a combination of them with
  weights that are not negative and sum to one, so `|C'(t)| ≤ M1`, the largest `|Q[j]|`.
- In the same way `|C'''(t)| ≤ M3`, the largest length of the control points of the third
  derivative, which is zero for a curve of degree 2. Those are differences of differences,
  and a computed difference of computed numbers can lose every digit. So `M3` is taken as
  its computed value plus `2^-40` times the same expression with every difference made a
  sum of magnitudes, which bounds what the differences lost. `M1` needs nothing of the
  kind: each of its differences is of two numbers the caller gave.
- `W1 = 2p / Δ1` and `W2 = 4p(p - 1) / (Δ1 Δ2)`, with `Δ1` the least `knot[j+p] - knot[j]`
  and `Δ2` the least `knot[j+p-1] - knot[j]` over the span's control points. They bound the
  sums of the basis contract's `S` for the first and the second derivative: each step of
  `S` multiplies the sum of the row before it by at most twice the degree reached over the
  least knot difference, and a row of values sums to one.

`A` is the largest magnitude of a coordinate of a control point, and `B` of the point `X`.

### The error of what is computed at a parameter

From [the curve contract's bound](spline-curve.md#the-error-bound), in which the weights
sum to one and `S` sums to at most `W`: writing `τ = (p + 2)² × 2^-1074`, each coordinate
of the computed point, first and second derivative is within

    ε0 = (γ(6p + 2) + τ) A  +  τ (A + 1)
    ε1 = (γ(6p + 2) + τ) A W1  +  τ (A (W1 + 1) + 1)
    ε2 = (γ(6p + 2) + τ) A W2  +  τ (A (W1 + 1) + 1)

of its exact value. Write `δ = C(t) - X`. Each computed coordinate of it is within
`E0 = ε0 + 2^-52 (A + B)` of exact. Lengths are computed scaled by their largest
coordinate, so that no square leaves the range; with `x̂` for a computed `x`:

| Quantity | Computed as | Its error is at most |
| --- | --- | --- |
| the distance `d = \|δ\|` | the length of `δ̂` | `e_d = D E0 + 2^-40 d̂` |
| the speed `s = \|C'\|` | the length of `Ĉ'` | `e_s = D ε1 + 2^-40 ŝ` |
| `a = \|C''\|` | the length of `Ĉ''` | `e_a = D ε2 + 2^-40 â` |
| the residual `g = δ · C'` | the sum of products | `e_g = ε1 \|δ̂\|₁ + E0 \|Ĉ'\|₁ + D E0 ε1 + 2^-40 Σ \|δ̂ Ĉ'\|` |
| `w = δ · C''` | the sum of products | `e_w = ε2 \|δ̂\|₁ + E0 \|Ĉ''\|₁ + D E0 ε2 + 2^-40 Σ \|δ̂ Ĉ''\|` |

A length is within the error of its vector, and `D` times the largest coordinate error
bounds that; the `2^-40` terms are the rounding of forming the length or the sum. `e_g` is
the bound returned among the measures.

### What follows for a whole interval

An interval `I` inside one span, with middle `m` and `r` at least the distance from `m` to
either end. With the quantities above computed at `m`, for every `t` in `I`:

    |C''(t)|        ≤  K2    =  â + e_a + M3 r
    |C'(t)|         ≥  sLow  =  ŝ - e_s - K2 r,  or zero if that is negative
    |C'(t)|         ≤  sUp   =  ŝ + e_s + K2 r
    |C(t) - X|      ≥  d̂ - e_d - M1 r
    |C(t) - X|      ≤  dUp   =  d̂ + e_d + M1 r

each by the mean value inequality from the bound on the next derivative. The derivative of
the residual along the curve is `h = C' · C' + δ · C''`. Since
`δ(t) · C''(t) = w(m) + (C(t) - C(m)) · C''(t) + δ(m) · (C''(t) - C''(m))`,

    h(t)   ≥  sLow² + ŵ - e_w - M1 r K2 - (d̂ + e_d) M3 r
    |h(t)| ≤  hUp  =  sUp² + dUp K2

and the residual at `t` differs from the residual at `m` by at most `hUp r`.

### The four tests of an interval

`U` is the least of `d̂ + e_d` over every parameter evaluated so far for this point: the
nearest point of the curve is no farther than that.

1. **Set aside by distance** when `d̂ > (U + tie + e_d + M1 r)(1 + 2^-40)`. Then every
   point of `I` is farther than `U + tie`, so `I` holds neither the nearest point nor a
   least point within `tie` of it.
2. **Rising** when `ĝ > (e_g + hUp r)(1 + 2^-40)`: the residual is above zero on all of
   `I`, the distance rises across it, and no least point of the curve's distance lies in
   `I` unless its left end is the start of the domain. That end is then a candidate.
   **Falling** is the same with the sign and the ends exchanged.
3. **Convex** when the lower bound of `h` above is shown above zero: with the terms that
   are not negative on each side, `sLow² + max(ŵ, 0)`, lowered by `1 - 2^-40`, against
   `max(-ŵ, 0) + e_w + M1 r K2 + (d̂ + e_d) M3 r`. The squared distance is then strictly
   convex on `I` and has one least point there. The residual is computed at the two ends
   of `I`, each with its `e_g`:
   - above its bound at the left end: the least point of `I` is its left end, a candidate
     if that is the start of the domain and otherwise not a least point of the curve;
   - below minus its bound at the right end: the same for the right end and the end of the
     domain;
   - below at the left and above at the right: a foot lies strictly between, and is found
     as the next section says;
   - otherwise the residual at an end is zero to within its bound, and that end is the
     candidate; where that is so at both ends, the nearer of them.
4. **Otherwise halved.** An interval that has been halved `depth` times is kept as
   unresolved, with the lower bound of the distance over it.

As an interval shrinks about a foot at which `h` is above zero, the lower bound of `h`
tends to `h` itself, so the convex test succeeds after finitely many halvings. That is why
the third derivative is in it: a bound from the second alone does not tend to anything.

### Finding a foot between two ends

A bracket whose left end has a residual shown below zero and whose right end one shown
above. The iterate starts at the middle. At each iterate the residual and `h` are
computed. If the residual is within its `e_g` of zero, the iterate is returned. Otherwise
it replaces the end of the bracket whose sign it shares; if the bracket is then no wider
than `step`, or its ends are neighbouring doubles, it is returned. The next iterate is
the Newton step where that lies strictly inside the bracket and the pass before at least
halved the bracket, and the bracket's middle otherwise.

Newton's method approaches from one side and can leave the other end of the bracket where
it was. So when a Newton step is shorter than a quarter of `step`, the residual is
computed half of `step` to each side of where it lands, inside the bracket. Signs shown
opposite there are the two parameters of the first promise, no more than `step` apart;
signs not shown at all are a residual within its bound; and anything else moves the
bracket and the iteration goes on. Of any two passes one at least halves the bracket, so
the search ends.

### Choosing among the candidates

Intervals are taken in increasing order of the parameter. A candidate from a convex
interval that begins where the convex interval of the candidate before it ended is the
same least point, since a function convex on each of two intervals that touch, with a
continuous derivative, is convex on both: the nearer of the two is kept and the other is
not a second answer.

With `d1`, `e1` the distance and its error at the nearest candidate:

- **`unresolved`** if there is no candidate, or if some unresolved interval's lower bound
  of the distance is at most `(d1 + e1 + tie)(1 + 2^-40)`;
- otherwise **`tied`** if another candidate's `d̂ - e_d` is at most that;
- otherwise `start`, `end` or `foot`, by the parameter.

**Why this is the nearest of the whole curve.** The distance is continuous on a closed
domain, so it has a least value, reached at a least point of the kinds above. Every
interval was set aside by test 1, which excludes it from holding anything within `tie` of
the nearest; or by test 2, which excludes a least point inside it; or was convex, and gave
its one least point as a candidate or showed it not to be one; or is unresolved and is
reported. So the nearest point is among the candidates, and any other least point within
`tie` of it is a candidate too or lies in an interval that is reported.

**A hint** is evaluated first and only lowers `U`. Where no hint is given the middle of
every span is evaluated first, for the same purpose. `U` enters test 1 alone, and what
test 1 sets aside with any `U` that is truly an upper bound holds nothing the promises
speak of.

## Derivatives of the foot, asked for apart

`differentiate!(search, controls, points, feet, reports, spans, by-point, by-controls) -> SearchStatus`

Not computed by `nearest!`, and so costing nothing to a caller that does not ask. For each
point whose report is `foot`:

- `by-point`, `dimension` doubles: the derivative of the foot's parameter with respect to
  each coordinate of the point, `C'(t) / h`.
- `by-controls`, `(p + 1) × dimension` doubles, and its span into `spans`: the derivative
  with respect to each coordinate of each control point of the span,
  `-(N[j](t) C'(t) + N'[j](t) (C(t) - X)) / h`.

Here `h = C'(t) · C'(t) + (C(t) - X) · C''(t)`, the derivative of the residual along the
curve. For a report of `start` or `end` the parameter does not move and both are zero.
Where the computed `h` is within its own error bound of zero, the point at a centre of
curvature, the derivative does not exist: that point's entries are not written and an
output of this call says so. That bound is `2 ε1 |Ĉ'|₁ + D ε1² + e_w`, with the rounding
of forming `h`. `h` can be well away from zero where the speed is nearly zero; the speed
among the measures is what tells a caller that.

## Outcomes of a call

`SearchStatus` is about the inputs, and a refusal writes nothing.

| SearchStatus | Meaning |
| --- | --- |
| SearchSuccess | Every point has its parameter, its report and its measures |
| SearchBadSize | An array's length is not what the call needs |
| SearchBadTolerance | `step` or `tie` is negative or not a number |
| SearchNonFinite | A coordinate of a point or of a control point, or a hint that is given, is not finite. The whole array of control points is checked: a search of the whole curve uses all of it |

An output that is one of the call's inputs, or another of its outputs, is the typed error
`OutputAliased`.

## What it does not do

- Curves of degree 1, and curves with a knot where the tangent can turn. A corner can be
  the nearest point without being a foot; it needs the derivative from each side, which
  the basis module does not yet give.
- The farthest point.
- Rational curves.
- A choice between two answers.

## Cost

Not measured. In count: the control points of each span are differenced once a call. For
each point, one evaluation of the curve for the hint, or one for each span where there is
none; then one for each span to set it aside or not; then, for each interval that
survives, a few halvings, two evaluations at its ends, and a Newton iteration of a handful
of steps with two more to close the bracket. Every evaluation is to the second order. A
point near a curve that does not fold back toward it costs a few tens of evaluations.

## Where the method is read

The convex hull property of a segment and of its derivative: the reference text, 5.7 and
5.6. Newton's method in floating point: Higham, chapter 25, to be read when the batch is
built. The bounds over an interval, the tests, the bracket and the rule for a tie are
derived above from those, from the two contracts this module stands on and from the mean
value inequality; no text to hand gives them and none was read for them.

## Settled with the first consumer before this draft

Its facts of 2026-11-23, each of which the draft is written to.

1. **The globally nearest foot at every step, with no memory.** A previous parameter may
   be offered as a hint for speed, never as a constraint.
2. **A near-tie is reported, not broken.** It would hand the step back.
3. **An end is returned exactly, with a flag** that it is an end and not a foot.
4. **The stopping tolerance is the caller's, in the units of the parameter.**
5. **The residual at the answer is returned with a bound.**
6. **Derivatives of the foot are optional** and cost nothing unless asked for.
7. **Many points against one array of control points.**
8. **A workspace for the search is this batch's**, not the curve module's.

## Settled with the first consumer on the draft

Its answers of 2026-11-23 to the draft's nine questions, and two behaviours it asked the
contract to be written to.

1. **A tie is the difference of the two distances from the point.**
2. **Reports are one array of codes.**
3. **Outcomes are for each point.** It hands back a whole step if any point is tied or
   unresolved.
4. **A bracket no wider than `step` may replace a step that changes the parameter by at
   most `step`.** It is the stronger rule.
5. **A point that exhausts `depth` is reported `unresolved`, and no parameter is returned
   for it.**
6. **Degree at least 2 and no knot where the tangent can turn** covers what it holds.
7. **Hints are an array that may have no entry.**
8. **Derivatives are a call of their own.**
9. **The whole array of control points is checked finite on every call.**
10. **The speed at the foot is returned**, since its own rule declines a foot where the
    speed is at most a small multiple of the size of the control points.
11. **An answer is interior only when its parameter is strictly inside the domain.** The
    report is decided by the parameter, as said above.
