# Conventions and terms

The mathematical conventions of the library, each fixed once, and the words its contracts
use. [The design notes](docs/design.md) say that an application's conventions are never
taken; these are the library's own, and a contract that departs from one says so.

A convention marked *provisional* is the one the first contract that needs it will be
written to. It becomes fixed when that module is built, and can still be argued about
until then.

## Numbers

- **Doubles.** Every coordinate, parameter and result is an IEEE double. No other
  floating-point type is offered.
- **Angles are in radians.**
- **No unit.** A length is a number. Its unit is the caller's.
- **A tolerance is always an argument**, in the units of what it is compared with, and the
  contract names the comparison.

## Space

- **Axes are right-handed.** In the plane, the positive sense of rotation is
  counter-clockwise: from the first axis toward the second.
- **A point of the plane is two numbers, x then y; of space, three, x then y then z.**
- **Points are held in arrays of coordinates, a point after a point**: point `i` of an
  array of points of the plane is at indices `2i` and `2i + 1`.
- **Vectors are columns.** A matrix acts on the left of a vector, and a matrix held in an
  array is held by columns, as in the sister library.

## Curves

- **A parameter runs over a closed interval**, the curve's domain, in the direction of
  increasing parameter. A parameter outside the domain is refused; it is never clamped
  into it.
- *Provisional.* **A circle or an ellipse is parametrized by angle from its first axis,
  counter-clockwise**, the parameter of a point taken in `[0, 2π)`.
- *Provisional.* **An arc is given by its curve and a parameter interval**, traversed with
  increasing parameter. An arc through the angle where the parameter wraps has an end
  parameter above `2π`.
- **A nearest point is a foot**: a point of the curve where the line to the given point is
  perpendicular to the curve, or an end of the domain. *Nearest* means the foot of least
  distance. Where two feet are at the same least distance the nearest point is not unique,
  and a call says so.

## Splines

- **A knot vector is a non-decreasing array.** With degree `p` and `n` control points it
  has `n + p + 1` knots, numbered from zero.
- **The domain is from knot `p` to knot `n`**, both ends included.
- **A span is an index `i` with knot `i` strictly below knot `i + 1`**; a parameter in the
  domain belongs to the one span whose half-open interval `[knot i, knot i + 1)` holds
  it, and the right end of the domain belongs to the last span.
- **Degree, not order.** A cubic has degree 3.

## Rotations

All provisional; they are fixed with the rotations module.

- **A unit quaternion is four numbers, the scalar part first**: `w, x, y, z`.
- **A quaternion and its negative are the same rotation.** A call that returns a
  quaternion returns the one with a non-negative scalar part; where the scalar part is
  zero the contract says which.
- **A rotation vector is an axis times an angle in radians**, the angle in `[0, π]`.
- **A rotation acts on a column vector from the left**, and a composition `a ∘ b` applies
  `b` first.

## Words

| Word | Meaning here |
| --- | --- |
| Batch (of work) | One module or one coherent addition, with its contract, tests, controls and record |
| Batch (of points) | Many points passed to one call |
| Branch | A place where a routine's answer is one of several, and which one changes discontinuously with the input |
| Contract | The page that says what a module's calls take, return, refuse and cost |
| Degenerate | An input for which the question has no single answer: coincident points, a zero direction, parallel lines |
| Foot | See *nearest point*, above |
| Refuse | Return a named status, or signal a typed error, having written nothing |
| Roster | A test that asks one question of every exported call, with its members read from the sources |
