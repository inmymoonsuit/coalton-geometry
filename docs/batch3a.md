# Batch 3a: an outside audit of the three spline modules

State: completed 2026-11-23. Robert Smith read the three modules as pushed and sent three
commits; they are on `main` as he wrote them, with one change after them that
[this record gives the reason for](#what-was-changed-after-it). Both complete checks pass
at safety 1 and safety 0 on Windows x86-64, SBCL 2.6.10 and the pinned Coalton compiler.

No signature changed, and nothing a call refuses or writes on a refusal.

## What the audit found

Each was reproduced on the sources as they were before it, and is fixed by his commits.

| Finding | What the old sources did | Now |
| --- | --- | --- |
| A residual that overflows counted as a residual of zero | For a straight line of length 2^516 and a point a quarter of the way along it, `nearest!` reported `start` at parameter 0, with a residual of minus infinity among the measures. A residual and a bound that are both infinite passed the test for "zero to within its bound" | A quantity or a bound that is not finite is evidence of nothing; the point is `unresolved` |
| A squared distance that overflows hid a tie | On a curve with two least points equally far, scaled by 2^512, one `foot` was reported. The floor of a candidate squared its distance | `tied`. The floor is formed without squaring a distance |
| A hint could cost an answer | With a budget of 21 intervals a point was reported `end` with no hint, and `unresolved` with a poor hint, and also with a hint outside the domain: a hint replaced the first upper bound instead of improving it, and one outside the domain left none | The same answer for every hint. The middles of the spans are evaluated first, hint or none, and a hint can only lower the bound they give |
| A bound of a span could be zero | `W2`, which bounds what the second derivative's rounding can be, divides by a product of two knot differences. On knots 2^512 apart the product overflowed and the bound came out zero | The two divisions are made one after the other |
| An intermediate too large refused a result that fits | The basis refused a second derivative on knots (-1024, -1024, -1024, 0, 2^-1030, 1024, 1024, 1024), where a quotient of the first step overflows and every entry asked for fits. A curve refused a point whose control points are 2^1023, where a partial sum overflows | Each is tried again with the exponent carried apart from the significand, and refused only if a result does not fit |
| The exact reference of the nearest-point tests could miss a least point | To learn the sign of the residual beside a root it stepped a fixed 2^-70 away, and two roots closer than that put it past the second. On `t((1+e)t - e)` with `e` of 3 × 2^-71, crossed twice by the point, it found one least point of two | The sign beside a root is that of the first Taylor coefficient that is not zero there |

A clamped end of the domain also has a second test of the sign of the residual there, from
the control points alone, which decides most ends that the computed residual leaves
undecided. An empty batch, and a search allowed no intervals, no longer prepare the curve.

The same commits rewrite parts of all three modules without changing what they do: the
slots of a workspace are named in one declaration that also gives its length, a parameter
is passed to the routines that use it and not kept in the handle, and sums and conditions
are written more directly. [The style notes](development.md) have what was taken from it.

## What was checked here

- **Both complete checks on his branch as sent**: pass at both safety policies, with 0 bytes
  allocated by every warmed call, and the family against the exact reference unchanged:
  357 answers, 249 feet, 81 ends, 22 tied, 5 unresolved.
- **His new tests against the old sources**: the basis fixture, the curve fixture, the
  bounds of a span, and the scale sweep each fail there. The cases of the table above were
  also put to both trees one at a time, by a script kept outside the repository.
- **Every planted defect on his branch**, which had to follow the sources he rewrote:
  19 of the basis, 12 of the curve and 16 of the search, one of them his own, each caught.
- **The old reference on his case**: it returns one least point where there are two.

## What was changed after it

One thing. His branch left **an end of the domain whose residual is zero to within its
bound** `unresolved`, on the ground that a small residual does not show the end to be the
least point. The sources before it reported that end, and they do again.

Measured on both trees, with a step of 10^-12:

| Point | Before the audit | His branch | Now |
| --- | --- | --- | --- |
| On the normal at a clamped start, or at a clamped end | `start`, `end` | unresolved | `start`, `end` |
| The start or the end of an unclamped curve itself | `start`, `end`, at distance 0 | unresolved | `start`, `end` |
| On the normal at an unclamped start | `start` | unresolved | `start` |
| Beyond an end; the first or the last control point of a clamped curve; a foot a millionth inside | the end; the end; the foot | the same | the same |

The reasons, with the first consumer's:

- **The parameter is right either way.** On an interval shown convex the least point is
  within `(|g| + e_g) / H` of that end in the parameter, which the first promise of the
  contract already covers. What the arithmetic cannot say is whether the least point is the
  end itself or a foot that close to it.
- **The caller is told which.** The residual and its bound are two of the measures. An end
  the distance strictly rises from has a residual beyond its bound; an end reached this way
  has one within it. [The contract](spline-nearest.md#the-report-for-a-point) now says so.
  A report that withholds the parameter cannot be decided better by a caller.
- **The consumer takes the end there.** A solver whose nearest point is at an end uses the
  end, and its own row for a point past an end is zero on the normal. Unresolved would hand
  every such step back.
- **His point about the derivative stands.** At such an end the derivative of the foot does
  not exist. That is a refusal for `differentiate!`, which is not built, and the contract
  keeps his text for it.

A point exactly on the normal at an end is an ordinary configuration, not a rare one, and
the end of an unclamped curve is the seam of a closed curve on periodic knots.

Thirteen answers are pinned, each held to the exact reference, and a planted defect that
leaves such an end unresolved is caught by them:
`python tools/plants.py tests/plants/batch3.py`.

## What it costs

- **A hinted search evaluates the middle of every span, as an unhinted one does.** One
  evaluation of the curve's value for each span that is not empty, for every point. The
  consumer accepted it: the tests of the intervals that follow cost far more, and it cannot
  know beforehand which of its hints are poor.
- **With the knots scaled by 2^-400 a point that was answered within the step is now
  unresolved.** The range answered exactly, 2^-300 to 2^300, is as it was.
- **The straight line of length 2^516 is unresolved**, not answered: the search's limit, as
  [batch 3's record](batch3.md#the-scale-sweep) has it for every scale that large.

## Limits

- **The figure of time in the contract's section on cost is the contributor's**, taken on
  his machine for an empty batch. No timing was taken here.
- **The exponent carried apart is read from the bits of a double** through two functions of
  the SBCL kernel, because the portable ones allocate. The library was already for 64-bit
  SBCL alone.
- What [batch 3's record](batch3.md#limits) lists is unchanged: the derivatives of the foot
  are not built, and a greatest distance within the tie leaves a point unresolved.
