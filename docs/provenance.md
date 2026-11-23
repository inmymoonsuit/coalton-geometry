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
| *none yet* | | | | |

## What was carried over

The check runner, the dependency registration, the toolchain checker and the machinery of
the two rosters were written for [coalton-linalg](https://github.com/inmymoonsuit/coalton-linalg),
by the same authors under the same licence, and copied here. Nothing else in this
repository comes from anywhere.

## The toolchain

The pinned compiler and its dependencies are named, with where each was obtained and its
content hashes, in [toolchain.sources.json](../toolchain.sources.json) and
[toolchain.lock.json](../toolchain.lock.json). None of them is redistributed here.
