# Developing a module

How a batch goes from a need to a commit. [The batch plan](plan.md) says which batches
there are and what each must have; this page is the order of work and the tools.

## The order

1. **Contract first.** Write the module's page in `docs/`: every call, what it writes and
   where, every refusal by name, what is allocated, its conventions, the four questions
   and the fifth answered. [The first one](spline-basis.md) is the pattern. Send it to the
   consumer and wait for its answer. No code before that.
2. **Provenance next.** Enter the method in [the register](provenance.md#the-register),
   cited to the page and the equation, with the form that was read. If the only source to
   hand is code, stop.
3. **The reference, before the implementation.** Write the test's independent reference,
   in exact rational arithmetic or stated high precision, by a route other than the one
   the implementation will take. Run it on a few cases by hand where the answer is known.
4. **The implementation**, a `.ct` file under `src/`, one package a file, added to
   `coalton-geometry.asd` under a `src` module. Statuses are enumerations, misuse is a
   typed error, data and results are in caller-owned arrays, and every check comes before
   the first write.
5. **The module's tests** under `tests/`, a Lisp file and, for anything measured, a `.ct`
   file of compiled callers in a package of its own: allocation is counted through a
   caller compiled in another file, never from the same file as the callee, for the reason
   [the design notes](design.md#how-a-point-is-held--decided) give.
6. **Both rosters.** The suite now fails, naming each new call that has no entry. Add the
   entries. For the scale sweep, declare an entry `:measure` first, read what it prints,
   and only then write the ranges down; a `:limit` is a finding to fix or to state in the
   contract, not a line to copy.
7. **Planted defects.** Write a roster under `tests/plants/` and run it. Every plant must
   compile and be caught. A plant that is missed means a test is missing or a fixture
   never reaches the code it guards; fix that, not the plant.
8. **Both checks**, safety 1 then safety 0, on the final tree.
9. **The record**, `docs/batchN.md`, and the changelog, roadmap and README. Then commit,
   and send the consumer's reviewer the commit range.

## The commands

All from the repository root, one at a time. `config.local.psd1` holds the machine's
paths; [setup](setup.md) says how to make it.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1 -Safety 0
```

The complete check at each safety policy. `-DynamicSpaceMb 1024` caps the Lisp heap on a
machine shared with other work.

```powershell
python tools\plants.py tests\plants\groundwork.py check
python tools\plants.py tests\plants\groundwork.py
```

The first verifies that every plant's site occurs exactly once, without running anything.
The second applies each plant alone, runs the complete check, restores the source, and
prints a verdict for each: `CAUGHT`, `MISSED`, or `INVALID` for a plant that did not
compile and so tested nothing. A `CAUGHT` line names the checks that noticed. Logs go
under `build/plants/`. Each batch has its roster: `tests/plants/batch1.py` is the first
module's.

On a machine shared with other work, the runner can be told to wait: set
`COALTON_GEOMETRY_PLANTS_WAIT` to a command that exits 0 when the machine is free, and it
is asked before every run. A command that only looks for another process is not a lock;
two waiters that both look and then start will overlap.

## Rules that were paid for

Each of these cost the sister library, or this one, a wrong conclusion before it was
written down.

- **A test written after a fix, and never seen to fail, proves only that it runs.** Watch
  it fail first.
- **A roster or a measurement that passes the first time has shown nothing yet.** The
  measurement of how a point is stored read zero for everything until its callers were
  moved to another file. Plant a defect and see it noticed.
- **A plant that does not compile is not a catch.** An edit that leaves a variable unused
  is refused by the compiler; keep the use.
- **A plant that is missed may be saying the code is not needed.** A mark put on a call to
  keep a number from being boxed was planted away and nothing allocated. The mark went,
  not the test.
- **A fixture worked out by hand is checked like anything else.** Four of the first
  module's were wrong and the module was right; each failed on the premise it asserted.
- **Scaling by a power of two changes nothing**, so a plant that only does that is the
  original program.
- **The compiler's warnings fail the build here.** It once went on after one and returned
  wrong numbers.
- **`when` and `unless` return nothing.** A branch of a `cond` beside them cannot return a
  value; wrap it.
- **A struct's field is read as `(.x p)`**, with no package prefix, and is not a symbol to
  export.
- **A fixture asserts its own premise.** If a test needs a matrix that pivots, a knot that
  repeats, a block that forms, it checks that it got one.
- **Never edit a tracked source while a check or a plant run is going.** It builds from
  the working tree.

## Style

Coalton as its developers write it: `cond` in place of nested or side-effecting `if`;
`when` and `unless` for effect only; a documentation string on every exported name and a
type declaration on every exported function; `for` in place of recursion for a loop;
`lisp` forms avoided, and factored into a function of their own where one is needed; one
package a file, with local nicknames. On the Lisp side: `loop` keywords written as
keywords, no `#'(lambda`, `case` keys in parentheses.
