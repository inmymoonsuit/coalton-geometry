# Roadmap

## Where it stands

**Ready to start, with nothing built.** The toolchain is pinned and checked, the two
rosters exist with no member, how a point is stored is measured and decided, the scope and
design are agreed, and [a batch plan](docs/plan.md) follows a first consumer's ranking.
[The groundwork's record](docs/batch0.md) has the evidence. No geometry is built.

## Before a first module

None of this is code.

1. ~~**The scope, agreed.**~~ Done 2026-11-22: [the design notes](docs/design.md) record
   what the library is, how data is held, how derivatives and branches are reported, and
   that it may depend on the sister library and does not yet.
2. **What the design notes still leave open**, where the first module meets it: the
   layout of a derivative in its array, how near to degenerate counts, and the
   mathematical conventions, fixed in each contract.
3. ~~**The consumer's review**~~ Done 2026-11-22: it accepted [the batch plan](docs/plan.md)
   and [the first module's contract](docs/spline-basis.md), answered the contract's five
   questions, and had one convention tightened.
4. **A reference text on splines**, for the citation the provenance rule asks for. None
   of the texts to hand treats B-splines.

## What a first consumer expects to need

The sister library's order of work came from its first consumer saying what it would use
first, and that kept it from building what nobody called. The same was asked here. This is
that consumer's list, a constraint solver written in Coalton, in the order it expects to
reach each need. It is a ranking, not a commitment, and nothing in it is started.

1. **Curves of the plane**, for a solver that holds points on them and makes them tangent:
   - B-spline basis functions and their derivatives to the order needed, with the
     derivatives at the ends.
   - The parameter of the nearest point of a curve to a given point: a global start, then
     a safeguarded Newton iteration. It is called for every held point at every step, so
     its cost per call matters.
   - For an ellipse: nearest and farthest points, the parameter of a given point, the
     radius of curvature, the quadrant points.
   - For a parabola: parameter, derivative, radius of curvature, construction from a
     focus.
   - Every such parameter with its derivative with respect to the inputs, by the implicit
     function theorem, so that a solver's Jacobian stays exact.
   - Lines, circles and arcs need only trigonometry; the consumer does those itself.
2. **Rotations**, for placing rigid bodies:
   - The exponential and the logarithm between a rotation vector and a unit quaternion,
     with series near zero and a branch near a half turn.
   - Composition, and the left and right Jacobians.
   - A quaternion and its negative treated as the one rotation they are.
   - The angle about an axis followed continuously across whole turns.
3. **Primitives whose derivatives behave where they kink**:
   - Distances and angles between points, lines, planes and axes.
   - An angle from the arctangent of a cross product and a dot product, never from an
     arccosine near its ends.
   - The distance between two lines with the parallel case named.
   - Where a derivative does not exist, the call says so and returns none.
4. **Later**: nearest points on a plane, a cylinder, a cone and a sphere, and on a curve
   of space. Freeform surfaces are a modelling kernel's.

Its terms are the sister library's: every contract holds or refuses by name; each batch is
reviewed from an export of a commit, against exact or high-precision arithmetic, by tests
the author has not seen; the four questions are asked of every routine; nothing is copied.
Where a consumer has an existing implementation it must agree with, agreement is the
consumer's to judge, and a difference has to be explainable, not zero.

## Candidates beyond that list

Named so that the boundary can be argued about, not as a plan.

- **Predicates of the plane**: orientation of three points, a point against a circle
  through three, a point against a segment. The exact sign, or a refusal.
- **Intersections** of lines, circles, arcs, ellipses and splines, with multiplicity
  reported and tangency named.
- **Knot insertion and subdivision** of a spline.

## Refused

- A modelling kernel: solids, boolean operations, topology, tessellation.
- Any tolerance, unit or drawing convention chosen by the library.
- A second linear algebra. What a module needs of that kind it takes from coalton-linalg.

## Tooling shared with the sister library

The check runner, the dependency registration, the toolchain checker and the two rosters'
machinery were copied from coalton-linalg, so that this repository can be cloned and
checked alone. They are two copies now. If the same change is ever needed in both, that is
the moment to lift them into one place both depend on, and not before. Until then each
library tells the other before changing its copy in a way the other should follow.

Hosted continuous integration on the pinned toolchain is wanted by both and built by
neither.
