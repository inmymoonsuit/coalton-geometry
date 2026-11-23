# The nearest parameter of a B-spline curve to a point

**State: draft contract for batch 3, sent to the library's first consumer on 2026-11-23
for its review. Nothing here is built, and nothing is until it signs.** The draft settles
the interface and what is promised. The constants of its bounds are derived, and added
here, before any code.

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
and no later call allocates. `depth` bounds the work spent on one point: how many times an
interval of the curve may be halved while looking for it.

The curve must be smooth enough to search. A typed error is raised, before anything is
allocated, for:

- a degree below 2;
- a basis made for an order below 2;
- an interior knot repeated more than `p - 1` times, where the tangent can turn or the
  curve can break.

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
- `measures`, `3 × count` doubles: the distance `|C(t) - X|`; the residual
  `(C(t) - X) · C'(t)` as computed at the returned parameter; and a bound on how far that
  computed residual can be from the exact one at that parameter.

### The report for a point

| Report | Meaning |
| --- | --- |
| `foot` | An interior foot, and the nearest point of the curve |
| `start`, `end` | The nearest point is that end of the domain, and it is not a foot: the residual there is not zero and points out of the domain |
| `tied` | A second part of the curve, apart from the one returned, is within `tie` of being as near. The parameter returned is the nearer of those found. The caller decides what to do; the library has not chosen for it |
| `unresolved` | The work allowed by `depth` ran out before the curve near the answer could be shown to hold one answer. The parameter returned is the nearest found. A curve that is a single point, or a point at the centre of an arc, ends here |

`tied` and `unresolved` are reports and not refusals: the other points of the batch are
answered, and the measures of this one are written.

### What is promised

Stated here as what the built contract will prove, with the arithmetic's own error
written in; the constants are derived before the code.

1. **A foot is a foot.** For a report of `foot`, the returned parameter lies in an
   interval no wider than `step`, or than the arithmetic allows, at whose ends the
   residual has opposite signs, and on which the squared distance is convex: it holds one
   foot and no other.
2. **Nearest means of the whole curve.** For a report of `foot`, `start` or `end`, every
   point of the curve outside that interval is farther than the returned distance by more
   than `tie`. Every part of the curve that was set aside was set aside by a bound that
   holds for all of it, not by sampling it.
3. **A second answer is never hidden.** If some part of the curve apart from the one
   returned could be within `tie` of as near, and the bounds cannot exclude it, the report
   is `tied`. The report errs toward saying so: it can say `tied` of a point that is only
   nearly so, and cannot fail to say it of one that is.
4. **A hint does not change any of this.**

## How it searches

In outline; the built contract has it in full with its derivation.

- **A bound for a whole interval of the curve.** A curve segment lies in the convex hull
  of the control points of its span, and so does its derivative curve in the hull of its
  own. So the speed of the curve over a span is at most the largest of the derivative's
  control points there, and a point of the curve at the middle of an interval bounds from
  below the distance to every point of the interval. An interval whose bound is above the
  least distance found so far, plus `tie`, holds no answer and is set aside whole.
- **Halving.** An interval that is not set aside, and on which the squared distance
  cannot yet be shown convex, is halved.
- **Convexity, then one foot.** Where a bound of the same kind shows the squared distance
  convex over an interval, the interval holds at most one least point: an interior foot,
  found by Newton's method kept inside a bracket that halves when a step would leave it,
  or an end of the interval.
- **The arithmetic's own error is inside every bound.** A part of the curve is set aside
  only when it is farther by more than the error of the evaluations that say so.

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
Where `h` is zero to within its own error bound, the point at a centre of curvature, the
derivative does not exist: that point's entries are not written and its report in an
output of this call says so.

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

Not measured. In count: one evaluation of the curve for each span that the hull of its
control points does not set aside at once; then, for each interval that survives, a few
halvings and a Newton iteration of a handful of steps, each one evaluation of the curve to
the second order. A point near a curve that does not fold back toward it costs a few tens
of evaluations; a hint that is right saves the first pass.

## Where the method is read

The convex hull property of a segment and of its derivative: the reference text, 5.7 and
5.6. Newton's method in floating point: Higham, chapter 25, to be read when the batch is
built. The bound over an interval, the test for convexity, the bracket and the rule for a
tie are derived in the built contract from those and from the mean value inequality; no
text to hand gives them and none was read for them.

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

## Questions for the consumer

1. **What a tie is.** This draft reports `tied` when a second part of the curve comes
   within `tie`, a length, of being as near as the first. You wrote of two feet within a
   distance of each other. Is the length the difference of their two distances from the
   point, as here, or the distance between the two feet themselves?
2. **Reports as one array of small codes**, `foot`, `start`, `end`, `tied`,
   `unresolved`. A tied answer is also a foot or an end. Do you want that kept, as a
   second array or as a code for each combination, or is `tied` alone enough since you
   hand the step back?
3. **Outcomes for each point, not one for the batch.** A tied or unresolved point does
   not refuse the batch. Only bad inputs do. Is that the shape you want, or should one
   tied point stop the call?
4. **The stopping rule is a bracket no wider than `step`**, not a step that changes the
   parameter by at most `step`. The first holds the foot inside it; the second does not
   promise that. Both come to the same parameter to within `step`. Does your agreement
   with the solver need the second rule itself?
5. **`depth` and the `unresolved` report.** A bound on the work is a number you choose
   when the handle is made. What should a point that exhausts it be to you: a step handed
   back, like a tie?
6. **Degree at least 2 and no knot where the tangent can turn.** Your cubics with simple
   interior knots are inside this. Is anything you hold outside it?
7. **Hints as an array that may have no entry.** Or two calls, one with hints and one
   without?
8. **Derivatives as a call of their own**, taking the feet the search returned. Is that
   what "only when asked" should look like?
9. **The whole array of control points is checked finite on every call**, unlike the
   curve module, because the search reads all of it.
