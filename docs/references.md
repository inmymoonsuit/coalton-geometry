# Reference texts

The texts this library's methods are read from, by work and edition: what each is read
for, what in each is not read, and what no text to hand covers. [Provenance](provenance.md)
has the rule and the register, which records each use to the page and the equation. This
page says where to look first, and it is kept so that an author and a reviewer hold the
same edition.

Nothing is cited from memory. A text is listed here once it has been opened and the
sections named below found in it. **How far each was read, as of 2026-11-23**: of the first
text, sections 5.3 to 5.9, 5.11, the first four problems of 5.12, and 4.8 were read as
pages, and what is said of them below is what they hold; of Higham, the pages of the three
results [the register](provenance.md#the-register) cites. Every other section on this page
is placed by its title, or by a
search for its terms, and has not been read; the batch that comes to it reads it then, and
corrects this page if the section turns out to hold something else.

## The texts held

| Work | Edition held | Read for | Limits |
| --- | --- | --- | --- |
| H. Prautzsch, W. Boehm and M. Paluszny, *Bézier and B-Spline Techniques* | Springer, 2002 (Mathematics and Visualization); softcover reprint of the first edition, ISBN 978-3-642-07842-2 | The spline modules: the basis, a curve and its derivatives, the step toward a nearest parameter | States its methods as mathematics and prose, with no listing in any language, so nothing in it is stepped over. Does not treat rational curves; its preface says so |
| A. Gray, E. Abbena and S. Salamon, *Modern Differential Geometry of Curves and Surfaces with Mathematica* | Third edition, Chapman & Hall/CRC, 2006 | Curvature and the turning angle of plane curves, evolutes and offsets, space curves, quaternions and rotations, surfaces later | **The notebook printed at the end of each chapter is a Mathematica listing and is not read.** Where the text says a result is verified in a notebook, the result is taken from the mathematics around it |
| P. Vannucci, *Tensor Algebra and Analysis for Engineers: With Applications to Differential Geometry of Curves and Surfaces* | World Scientific, 2023 | Rotations as tensors: axis and amplitude, composition, the small-rotation limit. Curvature of curves; the fundamental forms of surfaces later | No quaternions |
| K. Crane, *Discrete Differential Geometry: An Applied Introduction* | Course notes, the version dated 13 April 2020 | Its appendix A: derivatives of a length, an angle, an area, a normal and a unit vector with respect to the points that define them | Unfinished notes that say of themselves that they contain errors: a formula taken from them is derived again and tested against an independent reference. The coding exercises, and the codebase they belong to, are not read |
| G. Farin and D. Hansford, *Practical Linear Algebra: A Geometry Toolbox* | Fourth edition, CRC Press, 2022 | Distance from a point to a line and its foot, intersections of lines and planes, a conic brought to standard position | Introductory; Bézier curves only, no B-splines |
| N. J. Higham, *Accuracy and Stability of Numerical Algorithms* | Second edition, SIAM, 2002 | The model of floating-point arithmetic and the notation every error bound here is stated in; Newton's method in floating point | |
| A. P. Kiselev, *Geometry, Book II: Stereometry*, adapted by A. Givental | Sumizdat, 2008 | Definitions only: an angle between planes, a perpendicular to a plane, a cylinder, a cone | A school text by synthetic argument; no method is taken from it |

Also looked at and of no use here: R. Cavalieri and E. Miles, *Riemann Surfaces and
Algebraic Curves* (Cambridge, 2016), whose curves are complex ones studied for their
topology.

## Where each batch reads

Section and page numbers are the printed ones of the editions above.

### Batch 1, `spline/basis`, built

All in chapter 5 of Prautzsch, Boehm and Paluszny. [The register](provenance.md#the-register)
has what was used.

| What | Where |
| --- | --- |
| The recurrence that defines the basis, and the convention that a term whose knots coincide is zero | 5.3, pp. 61 to 62 |
| The derivative of a spline as a spline one degree lower, equation (1) | 5.6, p. 67 |
| The properties tested as identities: the sum is one, the support, positivity; and the derivative of one basis function | 5.7, p. 68 |
| Marsden's identity, its Problem 4, and the monomials written in the basis, which generalises it: the independent exact reference [the contract](spline-basis.md#how-it-will-be-checked) names | 5.12, p. 75, and 5.8, p. 69 |
| The basis as a divided difference of a truncated power: a second independent route | 5.11, p. 73 |

Three places where the contract departs from the text. They are the contract's own, and a
reviewer comparing the two should expect them.

- The text writes the second weight of the recurrence as one minus a ratio. The contract
  forms both weights as quotients, because [its error bound](spline-basis.md#the-error-bound)
  rests on nothing being subtracted that could cancel.
- The text's basis functions are continuous from the right everywhere, which leaves the
  right end of the domain outside every span. The contract closes the domain there and
  puts the right end in the last span.
- The text takes the knots as an unbounded sequence. The contract takes a finite vector
  and refuses a parameter outside its domain by name.

### Batch 2, `spline/curve`, built

Prautzsch, Boehm and Paluszny: a curve as the combination of its control points by the
basis, 5.5, p. 65, which is what the module computes; a point by repeated convex
combination, 5.4, p. 63, and the derivative as a curve one degree lower on differences of
the control points, 5.6, p. 67, equation (1), which are the routes its exact reference
takes; every derivative of a segment at a parameter, as its Taylor expansion, 5.9, p. 70.
**The rational curve is not in this batch and has no text here**: see below.

### Batch 3, `spline/nearest`

Prautzsch, Boehm and Paluszny, 4.8, p. 55: the parameter of a point near a curve improved
by the nearest point of the tangent. That is a first-order step. The plan's step uses the
second derivative as well and is safeguarded, and the section gives neither. Subdivision,
3.3, p. 27, for a start that does not depend on a guess. Higham, chapter 25, for what
Newton's method can deliver in floating point.

### Batches 4 and 5, `conic/ellipse` and `conic/parabola`

Gray, Abbena and Salamon: signed curvature of a plane curve, 1.4; evolutes, which are the
centres of curvature, 4.1; osculating circles, 4.4. Farin and Hansford, 19.3, for a conic
brought to standard position.

### Batch 6, `rotation`

Gray, Abbena and Salamon, chapter 23: orthogonal matrices, 23.1; quaternion algebra, 23.2;
unit quaternions and rotations, 23.3; and 1.5 for an angle followed as a continuous
function. Vannucci, 2.9 and 2.11: skew tensors and their axial vectors, rotations by axis
and amplitude, their composition, and the small-rotation limit.

### Batch 7, `measure`

Crane, appendix A.1: the derivatives of an edge length, an interior angle, a dihedral
angle, a triangle's normal, a unit vector and a cross product. Farin and Hansford, 3.6 and
3.7, for the distance of a point from a line and its foot. Kiselev for the definitions.

### Later, `surface`

Gray, Abbena and Salamon, chapters 10, 13 and 15; Vannucci, chapter 7.

## What no text to hand covers

Each is a need on [the plan](plan.md) with nothing yet to cite. None blocks batch 1.

- **Rational splines**, left out of batch 2 for want of a consumer and a text. The point
  and derivatives of a rational curve follow from the polynomial ones by the quotient
  rule, which may be all the citation needs; a text that treats them would settle the
  conventions for weights.
- **A safeguarded search for the nearest parameter**, for batch 3: the global start, the
  safeguard, and the derivative of the result by the implicit function theorem.
- **The nearest and farthest points of an ellipse**, for batch 4. The description best
  known is published beside code that implements it, which the rule excludes.
- **The derivative of the exponential map of rotations**, for batch 6: the left and right
  Jacobians, with their small-angle and near-half-turn forms. Neither rotation text here
  gives it, by its contents.
