# The rosters

Two questions are asked of every exported call at once, by test. They come from the sister
library, where an outside audit found defects the routines' own tests passed, and they
are in place here before the first call so that no call is ever outside them.
[The contributor notes](../CONTRIBUTING.md#four-questions-for-every-numeric-routine) have
the questions; [the sister library's page](https://github.com/inmymoonsuit/coalton-linalg/blob/main/docs/rosters.md)
has the same machinery with its members and what it found.

**The calls of the three modules are the members today**: four calls take more than one
array, and nine take or return floating-point numbers or return a status. Beside them run the
machinery's own controls.

## Membership is read from the sources

Each roster reads every `.ct` file under `src/`, takes the names its package exports, and
keeps those whose declared type fits a rule. It fails for a member with no entry and for
an entry that names no member. A call joins by being declared.

| Roster | A member is an exported function whose type |
| --- | --- |
| Aliasing | has two or more arrays among its own parameters |
| Scale sweep | mentions a floating-point number anywhere, or returns a status |

**These rules were written for a library whose data is arrays, and that is what this one
is**: [the design notes](design.md#how-a-point-is-held--decided) put held data and every
routine's results in caller-owned arrays of coordinates. Should a module ever take points
as values of their own, the aliasing rule would have nothing to see, and the question it
asks, an output that is also an input, would have to be asked of whatever can be written.

## The aliasing roster

[`tests/aliasing.lisp`](../tests/aliasing.lisp). A call given one array in two argument
positions either does exactly what it does with two arrays of equal contents, or refuses
before it writes anything. Each entry declares which, for each pair that could be one
array, and the roster fails when a pair does the other.

The roster asks only of arrays passed as arguments. An array a caller holds by another
route is outside it: the basis module's borrowed view of its knots, passed back as an
output, is such a case, refused by the module and tested by the module's own tests.

## The scale-sweep roster

[`tests/scale-sweep.lisp`](../tests/scale-sweep.lisp). Multiplying every input of a problem
by a power of two changes no significand, so every output has one right value at every
scale. Geometry is where this is plainest: scale a figure by two and every length doubles,
every area quadruples, and every angle, every parameter and every sign stays as it was.
An entry runs one small problem at twenty-five scales from 2^-1020 to 2^1020, says by what
power each output moves, and each run is put in a class:

| Class | The run |
| --- | --- |
| `:exact` | succeeded, and every output is its scaled value bit for bit |
| `:close` | succeeded, and every output is within the entry's tolerance of it |
| `:looser` | succeeded, and an upper bound came out above its scaled value, which a bound may |
| `:lost` | succeeded, and an output's right value is too small to be a normal number |
| `:refused` | refused, and some output's right value cannot be held at that scale |
| `:limit` | refused although every output's right value can be held |
| `:no-input` | was not made: an input is not a normal number at that scale |
| `:wrong` | succeeded with an output that is neither its right value nor lost |

`:wrong` fails wherever it appears. Every other class is declared by the entry as the
ranges it holds over, and the roster fails when a run leaves its declared class in either
direction.

A predicate is the hard case and the reason to have this from the start: an orientation
test computed as a difference of products gives a sign that the sweep will show changing
with scale as its products underflow, long before a module's own tests would.

## What the sweep does not ask

It multiplies a whole problem by one factor, so it does not ask about a figure whose own
coordinates lie far apart, or one far from the origin, which is the other way geometry
loses digits. Translation is not a power of two and is not exact. A roster for it, the
same figure moved, is a candidate once there is a module to ask it of.
