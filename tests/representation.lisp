(in-package #:coalton-geometry/tests)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (sb-ext:add-package-local-nickname "REP" "COALTON-GEOMETRY/TESTS/REPRESENTATION-CALLERS")
  (sb-ext:add-package-local-nickname "SUBJECT" "COALTON-GEOMETRY/TESTS/REPRESENTATION-SUBJECT"))

;;; How a point can be stored, measured. The figures are pinned: they are properties of the
;;; pinned compiler, the design in docs/design.md rests on them, and a compiler that changes one
;;; should be noticed here before it is noticed in a module.

(defparameter *representation-expected*
  '(("a point as a value, returned by a function" . 0)
    ("a point as a value, the function inlined" . 0)
    ("points in one array of coordinates" . 0)
    ("a number returned by a function" . 0)
    ("a number, the function inlined" . 0)
    ("a point as a value, kept in an array of points" . 32)
    ("a point as a value, returned by a function that is not inlined" . 96)
    ("a number returned by a function that is not inlined" . 80))
  "Bytes allocated a call by each way of holding a point, as (label . bytes), or :measure to print them.")

(defun run-representation-tests ()
  (let* ((coordinates (doubles 1d0 2d0 5d0 -4d0 0d0 0d0 0d0 0d0))
         (measured
           (list (cons "a point as a value, returned by a function"
                       (bytes-a-call (lambda (count) (rep:struct-loop coordinates count))))
                 (cons "a point as a value, the function inlined"
                       (bytes-a-call (lambda (count) (rep:inline-struct-loop coordinates count))))
                 (cons "points in one array of coordinates"
                       (bytes-a-call (lambda (count) (rep:array-loop coordinates count))))
                 (cons "a number returned by a function"
                       (bytes-a-call (lambda (count) (rep:scalar-loop coordinates count))))
                 (cons "a number, the function inlined"
                       (bytes-a-call (lambda (count) (rep:inline-scalar-loop coordinates count))))
                 (cons "a point as a value, kept in an array of points"
                       (let ((points (rep:make-points 1)))
                         (bytes-a-call (lambda (count) (rep:store-loop coordinates points count)))))
                 (cons "a point as a value, returned by a function that is not inlined"
                       (let ((held (subject:held-midpoint 1)))
                         (bytes-a-call (lambda (count) (rep:opaque-struct-loop held coordinates count)))))
                 (cons "a number returned by a function that is not inlined"
                       (let ((held (subject:held-cross 1)))
                         (bytes-a-call (lambda (count) (rep:opaque-scalar-loop held coordinates count))))))))
    ;; Each way computes the same thing: the midpoint (3, -1) and the cross product 1 * -4 - 2 * 5.
    (rep:struct-loop coordinates 1)
    (assert (and (= 3d0 (aref coordinates 4)) (= -1d0 (aref coordinates 5))) () "The midpoint is ~S." coordinates)
    (setf (aref coordinates 4) 0d0 (aref coordinates 5) 0d0)
    (rep:array-loop coordinates 1)
    (assert (and (= 3d0 (aref coordinates 4)) (= -1d0 (aref coordinates 5))) () "The midpoint is ~S." coordinates)
    (rep:scalar-loop coordinates 1)
    (assert (= -14d0 (aref coordinates 6)) () "The cross product is ~S." (aref coordinates 6))
    (dolist (entry measured)
      (format t "REPRESENTATION-MEASURED ~A: ~D bytes a call~%" (car entry) (cdr entry)))
    (cond
      ((eq *representation-expected* :measure)
       (format t "REPRESENTATION-MEASURED-ONLY~%"))
      (t
       (assert (equal measured *representation-expected*) ()
               "The ways of holding a point allocate~%  ~S~%and the figures the design rests on are~%  ~S"
               measured *representation-expected*)
       (format t "REPRESENTATION-PASS~%")))))
