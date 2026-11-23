"""Planted defects for the nearest-parameter search.

    python tools/plants.py tests/plants/batch3.py

Each is one edit to the module's source that a reader could make by mistake and that still
compiles. Each is applied alone and must be noticed by the checks. None of them can make a
search run without end: a plant that removed the budget would, and is not here.

Nor is one that offers the left end of every convex interval as a least point, where the
source offers it only at the start of the domain. It was planted and missed, and by the
derivation it changes nothing that can be seen: such an end is either merged with the
candidate of the convex interval it touches, or lies in what the test by distance has
already set aside.
"""

SOURCE = "src/spline/nearest.ct"

PASS_MARKS = ("SPLINE-CURVE-PASS", "SPLINE-NEAREST-REFERENCE-PASS", "SPLINE-NEAREST-REFUSALS-PASS",
              "SPLINE-NEAREST-ENDS-PASS",
              "SPLINE-NEAREST-KNOWN-PASS", "SPLINE-NEAREST-PASS", "SPLINE-NEAREST-BATCH-PASS",
              "ALIASING-ROSTER-PASS", "SCALE-SWEEP-PASS", "CHECK-PASS safety=1")

PLANTS = [
    (SOURCE, "an interval set aside by the distance at its middle, with nothing for how far the curve can go",
     "    (when (> d (* (+ (+ (arr:aref num n-upper) (arr:aref num n-tie)) reach) kept-up))",
     "    (when (> d (* (+ (+ (arr:aref num n-upper) (arr:aref num n-tie)) (min reach ed)) kept-up))"),
    (SOURCE, "the tie left out of the test that sets an interval aside",
     "    (when (> d (* (+ (+ (arr:aref num n-upper) (arr:aref num n-tie)) reach) kept-up))",
     "    (when (> d (* (+ (+ (arr:aref num n-upper) (* 0.0d0 (arr:aref num n-tie))) reach) kept-up))"),
    (SOURCE, "an interval taken to rise wherever the residual at its middle is above its own error",
     "    (when (> g drift)\n      (when (== low start)",
     "    (when (> g eg)\n      (when (== low start)"),
    (SOURCE, "an interval taken to be convex wherever the gain is above zero",
     "    (when (and (finite? gain) (> gain loss))",
     "    (when (and (finite? gain) (> gain 0.0d0))"),
    (SOURCE, "a second candidate judged by the distance at its parameter, not at its least point",
     "                      (least-floor (arr:aref num n-d) (arr:aref num n-ed) (arr:aref num n-g) (arr:aref num n-eg)\n"
     "                                   curvature)",
     "                      (if (> curvature 0.0d0) (end-floor (arr:aref num n-d) (arr:aref num n-ed)) 0.0d0)"),
    (SOURCE, "two candidates of convex intervals that touch taken for two least points",
     "(== (arr:aref state s-prev-convex) 1)", "(== (arr:aref state s-prev-convex) 2)"),
    (SOURCE, "the start of the domain never reported as the start",
     "                ((== parameter start) report-start)",
     "                ((< parameter start) report-start)"),
    (SOURCE, "a parameter returned for a point left unresolved",
     "    (arr:set! feet i math:nan)",
     "    (arr:set! feet i 0.0d0)"),
    (SOURCE, "a bracket taken for closed a million times too soon",
     "      (when (or (<= (- right left) step) (not (and (< left middle) (< middle right))))",
     "      (when (or (<= (- right left) (* 1000000.0d0 step)) (not (and (< left middle) (< middle right))))"),
    (SOURCE, "measures taken to be three numbers a point",
     "(product? (arr:length measures) count 4)", "(product? (arr:length measures) count 3)"),
    (SOURCE, "a tie of minus one accepted",
     "(>= tie 0.0d0)", "(>= tie -1.0d0)"),
    (SOURCE, "the hints not looked at for a number that is not finite",
     "(all-finite? hints)", "(all-finite? points)"),
    (SOURCE, "the parameters allowed to be the array of hints",
     "(unsafe-pointer-eq? feet hints)", "(unsafe-pointer-eq? measures hints)"),
    (SOURCE, "the speed of a span taken to be a quarter of its bound",
     "        (arr:set! (.mone store) s (+ (arr:aref (.mone store) s) tiny))",
     "        (arr:set! (.mone store) s (+ (* 0.25d0 (arr:aref (.mone store) s)) tiny))"),
    (SOURCE, "an interior knot allowed as often as the degree, where the tangent can turn",
     "      (when (and (== (arr:aref knots i) (arr:aref knots (+ i (- p 1))))",
     "      (when (and (== (arr:aref knots i) (arr:aref knots (min (- count 1) (+ i p))))"),
    (SOURCE, "an end of the domain whose residual is within its bound left unresolved",
     "      ((and (== left-sign Uncertain) (or (/= right-sign Uncertain) (<= d-lo (arr:aref num n-d))))",
     "      ((or (and (== low start) (== left-sign Uncertain)) (and (== high end) (== right-sign Uncertain)))\n"
     "       (loosen! num 0.0d0))\n"
     "      ((and (== left-sign Uncertain) (or (/= right-sign Uncertain) (<= d-lo (arr:aref num n-d))))"),
    (SOURCE, "a finite candidate's distance squared before scaling",
     "(let floor = (* (* low (math:sqrt (* (- 1.0d0 q) (+ 1.0d0 q)))) kept-down))",
     "(let floor = (* (* (math:sqrt (* low low)) (math:sqrt (* (- 1.0d0 q) (+ 1.0d0 q)))) kept-down))"),
]
