# Batch plan

State: reviewed and accepted by the library's first consumer on 2026-11-22. Nothing here
is built. [The roadmap](../ROADMAP.md) has the consumer's ranking this plan
follows; [the design notes](design.md) have the decisions every batch rests on.

A batch is one module, or one coherent addition to one, delivered whole: its contract, its
source, its tests against an independent reference, its entries in both rosters, its
planted defects, and a record of what was measured. The order below is the order of first
need, adjusted so that nothing is built before what it stands on.

## The batches

| Batch | Module | What it gives | Stands on |
| --- | --- | --- | --- |
| 1 | `spline/basis` | B-spline basis functions and their derivatives at a parameter, and for a batch of parameters | nothing |
| 2 | `spline/curve` | A point of a B-spline or rational B-spline curve and its derivatives with respect to the parameter, with the weights needed to differentiate with respect to the control points | 1 |
| 3 | `spline/nearest` | The parameter of the nearest point of a spline curve to each of a batch of points, with its derivatives and its branch report | 2 |
| 4 | `conic/ellipse` | For an ellipse: the parameter of a point, nearest and farthest points, radius of curvature, quadrant points, each with derivatives | nothing |
| 5 | `conic/parabola` | For a parabola: parameter, derivative, radius of curvature, construction from a focus | nothing |
| 6 | `rotation` | Exponential and logarithm between rotation vectors and unit quaternions, composition, left and right Jacobians, an angle followed across whole turns | nothing |
| 7 | `measure` | Distances and angles between points, lines, planes and axes, with derivatives named where they do not exist | nothing |
| later | `surface` | Nearest points on a plane, a cylinder, a cone, a sphere and a curve of space | 3, 7 |

Batches 4 to 7 stand on nothing before them and can be taken in whatever order the
consumer reaches them. Batch 1 is first because it is the smallest thing two later batches
need, and because it is where the conventions for arrays, batches and derivative layouts
are tried on something whose right answer can be computed exactly.

**Splines first, by the consumer's answer.** A solver's cost on a spline is the larger
one, since each held point is searched for many times in a step, and that is where a
compiled routine gains most. The conics have closed forms already and come after.

## What every batch has

The same things, so that a reviewer knows where to look.

- **A contract** in `docs/`, written and read by the consumer before the code: every call
  with its types, what it writes and where, every refusal by name, what is allocated, and
  the mathematical conventions it uses, by reference to [the conventions](../CONTEXT.md).
- **An independent reference.** Exact rational arithmetic wherever the answer is a rational
  function of the inputs, which covers the spline bases, curve points and their
  derivatives, and every closed form without a root. High-precision arithmetic, with the
  precision stated, where it is not: a nearest point, a logarithm. The reference is
  computed by a different route from the implementation's, never the same recurrence
  written twice.
- **Identities**, beside the reference: a basis sums to one; a derivative agrees with the
  difference of two exact evaluations to the order the mathematics says; an exponential
  followed by a logarithm returns its argument; a foot is perpendicular.
- **Entries in both rosters.** The scale sweep states each output's power: scale a figure
  by two and parameters, angles and basis values stay, lengths double, a derivative with
  respect to a parameter divides by two when the parameter scales.
- **The four questions answered in the contract**, and the fifth: what a degenerate input
  gets.
- **Planted defects** in a roster under `tests/plants/`, run by
  [`tools/plants.py`](../tools/plants.py): each applied alone, each compiled, each caught.
- **Allocation measured** in a compiled caller, at both safety policies: nothing in a
  warmed call.
- **A record**, `docs/batchN.md`: what was built, what was measured, what the controls
  caught, and the limits.
- **Provenance** entered before the code lands, cited to the page and the equation.

## Batch 1 in outline

[Its contract](spline-basis.md) is written and accepted, with an error bound derived
before the code. In short: a handle made once for a
degree and a highest derivative order owns the scratch; a call takes the knots, a
parameter or a batch of them, and caller-owned arrays, and writes the span and the values
of the basis functions that are not zero there, and of their derivatives. A knot vector
that is not one, a parameter outside the domain, and a derivative asked for where the
basis does not have it are each refused by name.

## What is needed before batch 1 can be built

- **A reference text on splines.** The texts to hand cover linear algebra, numerical
  stability and the geometry of conics and rotations, and none treats B-splines. The
  recurrence the basis rests on is published and standard, but
  [the provenance rule](provenance.md) asks for a citation to the page and the equation,
  and that needs the work in hand. A text that states the method in prose and mathematics
  serves; one whose algorithms are listings in a programming language is not read.
  Candidates, none yet obtained or read:
  - the two papers that introduced the recurrence: M. G. Cox, "The numerical evaluation
    of B-splines", *J. Inst. Maths Applics* 10 (1972), and C. de Boor, "On calculating
    with B-splines", *J. Approx. Theory* 6 (1972);
  - H. Prautzsch, W. Boehm and M. Paluszny, *Bézier and B-Spline Techniques* (Springer,
    2002), whose algorithms are stated as mathematics.

  Two standard works are poor fits for this rule. One states its algorithms as listings
  statement by statement, which invites exactly the comparison of structure the reviewer
  makes; the other carries programs in a real language, which are not read. The edition
  is to be agreed before anything is cited, so that author and reviewer hold the same one.
- **The consumer reaching it.** It comes to splines after other work of its own, and
  there is no hurry.

## Not planned

- Predicates, intersections, knot insertion and subdivision: candidates on the roadmap
  that nobody has asked for.
- Anything of general size in linear algebra. A batch that came to need it would take it
  from the sister library, and say so in its contract.
