# Provenance

## The rule

Every algorithm in this library is written from a published description of its method:
the mathematics, the prose, the error analysis. None is written from another
implementation's code.

- **Permitted**: textbooks, papers, standards and language documentation, read for what
  the method is and why it is right.
- **Never consulted or copied**: the source of any other geometry, modelling or numerical
  library, under any licence; a consumer's own implementation of the same thing; answers
  on a question site; a recollection of any of those. Close paraphrase of code is copying.
- **When the only source to hand is code**, the method is not used until a description is
  found. Say what the source is and stop.

### Pseudocode

The maintainer's ruling, 2026-11-22: clean-room style implementations are acceptable, in
the looser sense, and pseudocode may be read. In the strict sense of the phrase an
implementer sees no other implementation at all; this library does not claim that. What
it holds to is this.

1. **Pseudocode may be read to learn what a method is.**
2. **The implementation is written from the method's mathematics**, in a structure that
   follows from this library's own contract: caller-owned arrays, named refusals, every
   check before the first write. It is never a transliteration of a listing statement by
   statement, and it does not keep a listing's names.
3. **A listing in a real programming language is code and is not read.** Neither is
   pseudocode published under a licence, or beside code that implements it.
4. **The register says which form was read**, prose, mathematics or pseudocode, and cites
   it exactly: the work, its edition, the section, and the page and the number of the
   equation or algorithm.

The reasoning. Copyright protects an author's expression and not the method expressed: an
idea, procedure, process, system or method of operation is outside it however it is
described. A textbook's pseudocode is both at once. The method it states is free to use.
Its particular text, the order of its statements and its naming are the author's wherever
there was more than one way to write them, and a line-by-line rendering into another
language takes those. So the method is taken and the writing is not. This is a cautious
working rule, not legal advice.

**How it is checked.** The session that reviews each batch reads the cited source beside
the implementation and compares three things: the order of the statements with the order
of the listing's steps, where a one-to-one mapping is a finding; the identifiers with the
listing's names, standard mathematical symbols apart; and the comments and documentation
with the source's prose, where close paraphrase is a finding. Where the cited form is
prose or mathematics only, no comparison of structure is owed.

This matters more for geometry than for most subjects. Careful implementations of the
exact predicates are freely available and widely copied, and a modelling kernel's sources
may sit on the same machine as this checkout. Neither is a source for this library.

## The register

A method is entered here before the code that uses it lands: what it is, where its
description was read, that source's licence or status, and which file uses it.
[The reference texts](references.md) list the works held and their editions, and where
each planned batch expects to read; an entry here is the record that it did.

| Method | Read in: work, edition, section, page, equation or algorithm | Form read | Status of that source | Used by |
| --- | --- | --- | --- | --- |
| B-spline basis functions by the recurrence that defines each degree from the one below, with the convention that a term whose knots coincide is zero | Prautzsch, Boehm and Paluszny, *Bézier and B-Spline Techniques*, Springer 2002 (softcover reprint of the first edition): section 5.3, pp. 61 to 62, the recursion formula and the convention that follows it | Mathematics and prose; the text has no listing | In copyright; the method is taken and none of the text | `src/spline/basis.ct` |
| The derivative of a basis function as a difference of two of the degree below, each divided by a knot difference | The same: section 5.6, p. 67, equation (1); section 5.7, p. 68, the last property listed | Mathematics | As above | `src/spline/basis.ct` |
| Marsden's identity, from which the tests' exact reference is solved as a linear system | The same: section 5.12, p. 75, Problem 4; and section 5.8, p. 69, which generalises it | Mathematics | As above | `tests/spline-basis.lisp` |
| The model of rounding, with and without underflow, and the accumulation of rounding factors that the error bound is stated in | Higham, *Accuracy and Stability of Numerical Algorithms*, second edition, SIAM 2002: section 2.2, p. 40, equation (2.4); section 3.1, p. 63, Lemma 3.1; and the notes to chapter 2, p. 56, equation (2.8) | Mathematics | As above | `docs/spline-basis.md`, `tests/spline-basis.lisp` |

| A curve as the combination of its control points by the basis functions, which is what the curve module computes, and its derivative by the derivatives of those functions | Prautzsch, Boehm and Paluszny, as above: section 5.4, p. 63, the linear combination the section opens with; section 5.6, p. 67 | Mathematics | As above | `src/spline/curve.ct` |
| A point of a curve by repeated convex combination of its control points, and a derivative as the curve one degree lower on scaled differences of them: the two routes of the tests' exact reference | The same: section 5.4, p. 64, the affine combinations and their coefficient; section 5.6, p. 67, equation (1) | Mathematics | As above | `tests/spline-curve.lisp` |

| That a segment of a curve lies in the convex hull of the control points of its span, and its derivative in the hull of its own: what the search's bounds over a whole span rest on | The same: section 5.7, p. 69, the property of the convex hull; section 5.6, p. 67, equation (1) | Mathematics | As above | `src/spline/nearest.ct` |
| Sturm's count of the real roots of a polynomial in an interval, by which the tests' exact reference finds every least point of a distance | No text was read for it: it is used as a theorem of algebra, in the form of a chain of remainders with their signs changed, and the reference is checked on polynomials whose roots are known | A theorem, not a method read | | `tests/spline-nearest-reference.lisp` |

**What the search adds to those, because no text was read for it.** The bounds over an
interval, the four tests, the bracket with its Newton step, the lower bound of a least
point's distance and the rule for a tie are derived in
[the search's contract](spline-nearest.md#the-bounds-derived) from the hull property, the
two contracts the module stands on, the mean value inequality and the convexity of a
function whose second derivative is above zero.

**What the first two entries do not cover, because no text was read for it.** The text
gives the recurrence as a definition, not as a procedure. How the computation is arranged
is this library's, worked out from that definition and from what the contract's error
bound requires: the functions that are not zero on one span, taken degree by degree; each
function of a degree divided between the two of the next that it feeds, by two weights
that are each formed as a quotient; every degree kept, so that a derivative of order `m`
can start from the values of degree `p - m` and be raised one degree at a time. The error
bound and its two underflow terms are derived in [the contract](spline-basis.md#the-error-bound)
from Higham's model and are not taken from a text.

## What was carried over

The check runner, the dependency registration, the toolchain checker and the machinery of
the two rosters were written for [coalton-linalg](https://github.com/inmymoonsuit/coalton-linalg),
by the same authors under the same licence, and copied here. Nothing else in this
repository comes from anywhere.

## The toolchain

The pinned compiler and its dependencies are named, with where each was obtained and its
content hashes, in [toolchain.sources.json](../toolchain.sources.json) and
[toolchain.lock.json](../toolchain.lock.json). None of them is redistributed here.
