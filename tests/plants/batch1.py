"""Planted defects for the B-spline basis.

    python tools/plants.py tests/plants/batch1.py

Each is one edit to the module's source that a reader could make by mistake and that still
compiles. Each is applied alone and must be noticed by the checks. The line the runner prints
names the checks that noticed.
"""

SOURCE = "src/spline/basis.ct"

PASS_MARKS = ("SPLINE-BASIS-REFERENCE-PASS", "SPLINE-BASIS-KNOT-RULES-PASS", "SPLINE-BASIS-REFUSALS-PASS",
              "SPLINE-BASIS-BATCH-PASS", "SPLINE-BASIS-PASS", "SPLINE-BASIS-EXTREMES-PASS",
              "SPLINE-BASIS-ALLOCATION-PASS", "ALIASING-ROSTER-PASS", "SCALE-SWEEP-PASS", "CHECK-PASS safety=1")

PLANTS = [
    (SOURCE, "the second weight formed as one less the first, which the contract forbids",
     "        (let falling = (/ (- upper u) spread))",
     "        (let falling = (- 1.0d0 rising))"),
    (SOURCE, "a parameter equal to a knot placed in the span on its left",
     "(<= (arr:aref knot middle) u)", "(< (arr:aref knot middle) u)"),
    (SOURCE, "the end of the domain not given to the last span",
     "    (when (>= u (arr:aref knot controls))\n      (return (.final store)))",
     "    (when (> u (arr:aref knot controls))\n      (return (.final store)))"),
    (SOURCE, "the last span taken to be the first one",
     ":returns i :while (== (arr:aref knots i) end)",
     ":returns degree :while (== (arr:aref knots i) end)"),
    (SOURCE, "a derivative multiplied by one less than the degree it has reached",
     "        (let scale = (math:integral->num d))",
     "        (let scale = (math:integral->num (- d 1)))"),
    (SOURCE, "a derivative's difference taken the other way round",
     "(* scale (- (arr:aref ratio (- r 1)) (arr:aref ratio r)))",
     "(* scale (- (arr:aref ratio r) (arr:aref ratio (- r 1))))"),
    (SOURCE, "one derivative more allowed at a repeated interior knot",
     "(<= (multiplicity store span) (- p order))",
     "(<= (multiplicity store span) (+ (- p order) 1))"),
    (SOURCE, "the shortcut for knots that are not repeated taken one order too far",
     "    (when (and (<= order p) (<= (.crowd store) (- p order)))",
     "    (when (and (<= order p) (<= (.crowd store) (+ (- p order) 1)))"),
    (SOURCE, "a batch checked only as far as its first parameter",
     "    (for ((i 0 (+ i 1))) :while (< i count)\n      (let status = (admit",
     "    (for ((i 0 (+ i 1))) :while (< i (min count 1))\n      (let status = (admit"),
    (SOURCE, "a parameter above the domain let through",
     "    (when (or (< u (arr:aref knot p)) (> u (arr:aref knot controls)))\n      (return BasisOutsideDomain))",
     "    (when (< u (arr:aref knot p))\n      (return BasisOutsideDomain))"),
    (SOURCE, "orders above the degree left as the caller's array had them",
     "    (for ((i computed (+ i 1))) :while (< i all)\n      (arr:set! out (+ offset i) 0.0d0)))",
     "    (for ((i computed (+ i 1))) :while (< i all)\n      (arr:set! out (+ offset i) (arr:aref out (+ offset i)))))"),
    (SOURCE, "a knot allowed one repeat more than the degree and one",
     "      (when (== (arr:aref knots i) (arr:aref knots (+ i width)))\n        (throw (KnotRepeatedTooOften i))))",
     "      (when (and (< (+ (+ i width) 1) count) (== (arr:aref knots i) (arr:aref knots (+ (+ i width) 1))))\n"
     "        (throw (KnotRepeatedTooOften i))))"),
    (SOURCE, "a knot equal to the one before it refused as decreasing",
     "      (when (< (arr:aref knots i) (arr:aref knots (- i 1)))\n        (throw (KnotsDecrease i))))",
     "      (when (<= (arr:aref knots i) (arr:aref knots (- i 1)))\n        (throw (KnotsDecrease i))))"),
    (SOURCE, "the output of one evaluation allowed to be the basis's own knots",
     "    (when (unsafe-pointer-eq? out (.knot store))\n"
     "      (throw (OutputAliased \"The output is the basis's own knots.\")))\n"
     "    (when (> order (.limit store))\n      (return BasisBadOrder))\n"
     "    (unless (holds-exactly? (arr:length out) 1 order",
     "    (when (and (> order (.limit store)) (unsafe-pointer-eq? out (.knot store)))\n"
     "      (throw (OutputAliased \"The output is the basis's own knots.\")))\n"
     "    (when (> order (.limit store))\n      (return BasisBadOrder))\n"
     "    (unless (holds-exactly? (arr:length out) 1 order"),
    (SOURCE, "the output of a batch allowed to be its array of parameters",
     "    (when (unsafe-pointer-eq? out parameters)",
     "    (when (and (> order (.limit store)) (unsafe-pointer-eq? out parameters))"),
    (SOURCE, "a derivative too large to hold delivered as it is",
     "      (unless (finite? (arr:aref stage i))\n        (return (retry-derivatives!",
     "      (unless (or (> i 0) (finite? (arr:aref stage i)))\n        (return (retry-derivatives!"),
    (SOURCE, "the latest span cleared by a call that is then refused",
     "    (let status = (admit store parameter order))",
     "    (let status = (admit store parameter order))\n    (cell:write! (.last-span store) 0)"),
    (SOURCE, "the position of a refused parameter reported one late",
     "      (unless (== status BasisSuccess)\n        (cell:write! (.refused store) i)",
     "      (unless (== status BasisSuccess)\n        (cell:write! (.refused store) (+ i 1))"),
    (SOURCE, "the length of an output accepted when it is too long",
     "(lisp (-> Boolean) (entries blocks order width) (cl:= entries (cl:* blocks (cl:+ order 1) width))))",
     "(lisp (-> Boolean) (entries blocks order width) (cl:>= entries (cl:* blocks (cl:+ order 1) width))))"),
]
