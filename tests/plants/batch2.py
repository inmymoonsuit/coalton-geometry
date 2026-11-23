"""Planted defects for the B-spline curve.

    python tools/plants.py tests/plants/batch2.py

Each is one edit to the module's source that a reader could make by mistake and that still
compiles. Each is applied alone and must be noticed by the checks.
"""

SOURCE = "src/spline/curve.ct"

PASS_MARKS = ("SPLINE-BASIS-PASS", "SPLINE-CURVE-REFERENCE-PASS", "SPLINE-CURVE-REFUSALS-PASS",
              "SPLINE-CURVE-BATCH-PASS", "SPLINE-CURVE-PASS", "SPLINE-CURVE-UNDERFLOW-PASS",
              "SPLINE-CURVE-ALLOCATION-PASS",
              "ALIASING-ROSTER-PASS", "SCALE-SWEEP-PASS", "CHECK-PASS safety=1")

PLANTS = [
    (SOURCE, "the coordinates of a sum taken one apart, not a dimension apart",
     "(arr:aref controls (+ from (* r dimension)))",
     "(arr:aref controls (+ from (* r (min dimension 1))))"),
    (SOURCE, "the first control point of the span taken one too high",
     "    (let first = (- (basis:latest-span handle) p))",
     "    (let first = (+ (- (basis:latest-span handle) p) 1))"),
    (SOURCE, "a second derivative written from the row of the first",
     "        (arr:set! out (+ offset (+ (* m dimension) c))\n"
     "                  (combine rows (+ at (* m width)) controls (+ (* first dimension) c) dimension width))))",
     "        (arr:set! out (+ offset (+ (* m dimension) c))\n"
     "                  (combine rows (+ at (* (min m 1) width)) controls (+ (* first dimension) c) dimension width))))"),
    (SOURCE, "a result that is not finite written as it is",
     "    (unless (sums-finite? rows 0 controls first dimension width computed)",
     "    (unless (or (> width 0) (sums-finite? rows 0 controls first dimension width computed))"),
    (SOURCE, "a batch's results checked only as far as its first parameter",
     "    (for ((i 0 (+ i 1))) :while (< i count)\n      (unless (sums-finite?",
     "    (for ((i 0 (+ i 1))) :while (< i (min count 1))\n      (unless (sums-finite?"),
    (SOURCE, "orders above the degree left as the caller's array had them",
     "      (arr:set! out (+ offset i) 0.0d0)))",
     "      (arr:set! out (+ offset i) (arr:aref out (+ offset i)))))"),
    (SOURCE, "the result of one evaluation allowed to be the basis's own knots",
     "                  (or (unsafe-pointer-eq? out controls)\n"
     "                      (or (unsafe-pointer-eq? rows knots) (unsafe-pointer-eq? out knots)))))",
     "                  (or (unsafe-pointer-eq? out controls)\n"
     "                      (or (unsafe-pointer-eq? rows knots) (unsafe-pointer-eq? rows knots)))))"),
    (SOURCE, "the result of a batch allowed to be its parameters",
     "                          (or (unsafe-pointer-eq? out parameters)",
     "                          (or (unsafe-pointer-eq? rows parameters)"),
    (SOURCE, "the rows and the result of a batch allowed to be one array",
     "    (when (or (unsafe-pointer-eq? rows out)\n"
     "              (or (unsafe-pointer-eq? rows controls)\n"
     "                  (or (unsafe-pointer-eq? out controls)\n"
     "                      (or (unsafe-pointer-eq? rows parameters)",
     "    (when (or (unsafe-pointer-eq? rows controls)\n"
     "              (or (unsafe-pointer-eq? rows controls)\n"
     "                  (or (unsafe-pointer-eq? out controls)\n"
     "                      (or (unsafe-pointer-eq? rows parameters)"),
    (SOURCE, "an array of control points accepted when it is too long",
     "                 (and (holds-exactly? (arr:length controls) (basis:control-count handle) 0 dimension)\n"
     "                      (holds-exactly? (arr:length out) 1 order dimension)))",
     "                 (and (>= (arr:length controls) (* (basis:control-count handle) dimension))\n"
     "                      (holds-exactly? (arr:length out) 1 order dimension)))"),
    (SOURCE, "no dimension accepted",
     "    (unless (and (> dimension 0)\n"
     "                 (and (holds-exactly? (arr:length controls) (basis:control-count handle) 0 dimension)\n"
     "                      (holds-exactly? (arr:length out) 1 order dimension)))",
     "    (unless (and (>= dimension 0)\n"
     "                 (and (holds-exactly? (arr:length controls) (basis:control-count handle) 0 dimension)\n"
     "                      (holds-exactly? (arr:length out) 1 order dimension)))"),
    (SOURCE, "the results of a batch placed a block of rows apart",
     "                   (* i out-block)))",
     "                   (* i (max out-block row-block))))"),
]
