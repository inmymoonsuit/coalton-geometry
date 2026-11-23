# Provenance

## The rule

Every algorithm in this library is written from a published description of its method:
the mathematics, the prose, the error analysis. None is written from another
implementation's code.

- **Permitted**: textbooks, papers, standards and language documentation, read for what
  the method is and why it is right.
- **Never consulted or copied**: the source of any other geometry, modelling or numerical
  library, under any licence; code listings published beside a paper; answers on a
  question site; a recollection of any of those. Close paraphrase of code is copying.
- **When the only source to hand is code**, the method is not used until a description is
  found. Say what the source is and stop.

This matters more for geometry than for most subjects. Careful implementations of the
exact predicates are freely available and widely copied, and a modelling kernel's sources
may sit on the same machine as this checkout. Neither is a source for this library.

## The register

A method is entered here before the code that uses it lands: what it is, where its
description was read, that source's licence or status, and which file uses it.

| Method | Description read in | Status of that source | Used by |
| --- | --- | --- | --- |
| *none yet* | | | |

## What was carried over

The check runner, the dependency registration, the toolchain checker and the machinery of
the two rosters were written for [coalton-linalg](https://github.com/inmymoonsuit/coalton-linalg),
by the same authors under the same licence, and copied here. Nothing else in this
repository comes from anywhere.

## The toolchain

The pinned compiler and its dependencies are named, with where each was obtained and its
content hashes, in [toolchain.sources.json](../toolchain.sources.json) and
[toolchain.lock.json](../toolchain.lock.json). None of them is redistributed here.
