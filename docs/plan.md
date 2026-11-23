# Batch plan

State: reviewed and accepted by the library's first consumer on 2026-11-22. **Batch 1 is
built** ([its record](batch1.md)); nothing else is. [The roadmap](../ROADMAP.md) has the
consumer's ranking this plan follows; [the design notes](design.md) have the decisions
every batch rests on.

**Batches 2 and 3 go as far as a contract first.** The consumer asked, on 2026-11-23, for
each to be sent as a draft contract for its review, with code after it signs: the
derivatives with respect to control points and the interface of the batched search are
where its answers shape the design.

A batch is one module, or one coherent addition to one, delivered whole: its contract, its
source, its tests against an independent reference, its entries in both rosters, its
planted defects, and a record of what was measured. The order below is the order of first
need, adjusted so that nothing is built before what it stands on.

## The batches

| Batch | Module | What it gives | Stands on |
| --- | --- | --- | --- |
| 1, built | `spline/basis` | B-spline basis functions and their derivatives at a parameter, and for a batch of parameters | nothing |
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

[Its contract](spline-basis.md) was written and accepted, with an error bound derived
before the code, and is built. In short: a handle made once for a
degree and a highest derivative order owns the scratch; a call takes the knots, a
parameter or a batch of them, and caller-owned arrays, and writes the span and the values
of the basis functions that are not zero there, and of their derivatives. A knot vector
that is not one, a parameter outside the domain, and a derivative asked for where the
basis does not have it are each refused by name.

## What was needed before batch 1 could be built

- ~~**A reference text on splines.**~~ In hand since 2026-11-23: H. Prautzsch, W. Boehm
  and M. Paluszny, *Bézier and B-Spline Techniques* (Springer, 2002). Its chapter 5 states
  the recurrence, the convention for knots that coincide, the derivative, and the identity
  the independent reference rests on, all as mathematics and prose with no listing, so it
  fits [the provenance rule](provenance.md) as it stands.
  [The reference texts](references.md) name the edition and the sections batch 1 reads,
  and the three places where the contract departs from the text. The reviewer reads the
  same copy.
- ~~**The consumer reaching it.**~~ On 2026-11-23 it asked for the batch ahead of its own
  need, so that the module is reviewed and ready when it comes to splines.

Later batches have needs that no text to hand covers; the same page lists them. None
blocks batch 1.

## Not planned

- Predicates, intersections, knot insertion and subdivision: candidates on the roadmap
  that nobody has asked for.
- Anything of general size in linear algebra. A batch that came to need it would take it
  from the sister library, and say so in its contract.
