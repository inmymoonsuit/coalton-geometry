"""Planted defects for the groundwork: the measurement of how a point is stored, and the plant runner itself.

    python tools/plants.py tests/plants/groundwork.py

There is no library source to plant in yet. These plants are in the measurement's own subject
file, and show that its checks of the computed values bite; the last one is the runner's
control, a plant that does not compile and must be reported as INVALID and not as caught.
"""

SUBJECT = "tests/representation-subject.ct"
CALLERS = "tests/representation-callers.ct"

PASS_MARKS = ("REPRESENTATION-PASS", "ALIASING-ROSTER-PASS", "SCALE-SWEEP-PASS", "CHECK-PASS safety=1")

PLANTS = [
    (SUBJECT, "the midpoint written into the array is a quarter of the sum",
     "              (* 0.5d0 (+ (arr:aref coordinates (* 2 a)) (arr:aref coordinates (* 2 b)))))",
     "              (* 0.25d0 (+ (arr:aref coordinates (* 2 a)) (arr:aref coordinates (* 2 b)))))"),
    (SUBJECT, "the cross product adds its two products",
     '    "The cross product of two vectors of the plane, returned as a number."\n    (- (* ax by) (* ay bx)))',
     '    "The cross product of two vectors of the plane, returned as a number."\n    (+ (* ax by) (* ay bx)))'),
    (CALLERS, "a point that is kept is no longer kept, so nothing is allocated",
     "      (arr:set! points 0 (subject:midpoint a b))",
     "      (arr:set! points 0 (arr:aref points (if (< (.x a) (.x b)) 0 0)))"),
    (SUBJECT, "the runner's control: a declaration that does not match its definition",
     "  (declare cross (F64 * F64 * F64 * F64 -> F64))",
     "  (declare cross (F64 * F64 * F64 -> F64))",
     "INVALID"),
]
