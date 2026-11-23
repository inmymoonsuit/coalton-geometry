(in-package #:coalton-geometry/tests)

(defun run-tests ()
  "Every check of the library. Run through scripts/check.ps1, which pauses the finalizer for the measurements."
  (allocation-control-test)
  (run-representation-tests)
  (run-spline-basis-tests)
  (run-spline-curve-tests)
  (exact-nearest-reference-tests)
  (run-aliasing-tests)
  (run-scale-sweep-tests)
  (format t "TESTS-PASS~%"))
