(in-package #:coalton-geometry/tests)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (sb-ext:add-package-local-nickname "CURVE" "COALTON-GEOMETRY/SPLINE/CURVE")
  (sb-ext:add-package-local-nickname "CC" "COALTON-GEOMETRY/TESTS/SPLINE-CURVE-CALLERS"))

;;; A B-spline curve against docs/spline-curve.md. Every coordinate the module returns is
;;; compared with an exact one, computed in rationals by a route that forms no basis function:
;;; the point by repeated convex combination of the control points, and each derivative as the
;;; curve one degree lower on the scaled differences of the control points. The tolerance is the
;;; contract's bound, whose sums are computed exactly from the basis tests' own reference.

;;; ---- The exact reference ---------------------------------------------------------------------

(defun exact-combination (knots degree span u coefficients)
  "The value at U, exactly, of the curve of this degree whose coefficients on SPAN are COEFFICIENTS, a list for the
functions numbered SPAN - DEGREE to SPAN, by repeated convex combination: level r replaces coefficient j by
(1 - a) c[j-1] + a c[j] with a = (u - knot[j]) / (knot[j + degree + 1 - r] - knot[j])."
  (let ((c (coerce coefficients 'vector)) (base (- span degree)))
    (loop :for r :from 1 :to degree
          :do (loop :for j :from span :downto (+ base r)
                    :do (let ((a (/ (- u (aref knots j)) (- (aref knots (+ j degree 1 (- r))) (aref knots j)))))
                          (setf (aref c (- j base)) (+ (* (- 1 a) (aref c (- j base 1))) (* a (aref c (- j base))))))))
    (aref c degree)))

(defun exact-curve-column (knots degree span u coefficients order)
  "The value and the derivatives to ORDER at U, exactly, of one coordinate of a curve. The derivative of a curve of
degree d is the curve of degree d - 1 whose coefficient j is d (c[j] - c[j-1]) / (knot[j + d] - knot[j])."
  (let ((c coefficients) (found '()))
    (loop :for m :from 0 :to order
          :do (let ((d (- degree m)))
                (cond
                  ((minusp d) (push 0 found))
                  (t
                   (push (exact-combination knots d span u c) found)
                   (when (plusp d)
                     ;; C holds the functions numbered SPAN - D to SPAN; the next holds one fewer.
                     (setf c (loop :for j :from (1+ (- span d)) :to span
                                   :for index :from 1
                                   :collect (/ (* d (- (nth index c) (nth (1- index) c)))
                                               (- (aref knots (+ j d)) (aref knots j))))))))))
    (nreverse found)))

(defun exact-curve-reference-tests ()
  "The reference itself, where the answer is known in closed form."
  (flet ((rationals (&rest knots) (coerce knots 'vector)))
    ;; A segment: the point a quarter of the way along, and its constant slope.
    (assert (equal '(5/2 6 0) (exact-curve-column (rationals 0 0 1 1) 1 1 1/4 '(1 7) 2)))
    ;; A cubic with no interior knot is a Bezier curve: at 1/4 its Bernstein weights are
    ;; 27/64, 27/64, 9/64, 1/64, and its derivative is three times the lower curve on differences.
    (let ((c '(2 -1 5 3)) (u 1/4))
      (assert (equal (list (+ (* 27/64 2) (* 27/64 -1) (* 9/64 5) (* 1/64 3))
                           (* 3 (+ (* 9/16 -3) (* 6/16 6) (* 1/16 -2)))
                           (* 6 (+ (* 3/4 9) (* 1/4 -8)))
                           (* 6 -17)
                           0)
                     (exact-curve-column (rationals 0 0 0 0 1 1 1 1) 3 3 u c 4))))
    ;; Coefficients at the averages of the knots each function spans reproduce the line y = u.
    (let ((knots (rationals 0 0 0 1 3 4 4 4)))
      (assert (equal '(5/2 1 0) (exact-curve-column knots 2 3 5/2 '(1/2 2 7/2) 2)))))
  (format t "SPLINE-CURVE-REFERENCE-PASS~%"))

;;; ---- One evaluation against the reference ---------------------------------------------------

(defstruct curve-record (evaluations 0) (numbers 0) (ratio 0) (floored 0))

(defun curve-compare (label knots rationals degree dimension controls span u order out offset record)
  "The block of (ORDER + 1) DIMENSION numbers at OFFSET of OUT against the exact curve, to the contract's bound."
  (let* ((gamma (basis-gamma (1+ (* 6 degree)))) (first (- span degree)) (ur (rational u))
         (product-loss (* (1+ degree) (expt 2 -1075)))
         (value-loss (* (1+ degree) (+ 2 degree) (expt 2 -1074))))
    (declare (ignorable knots))
    (incf (curve-record-evaluations record))
    (dotimes (c dimension)
      (let* ((coefficients (loop :for j :from first :to span :collect (rational (aref controls (+ (* j dimension) c)))))
             (magnitudes (mapcar #'abs coefficients))
             (exact (exact-curve-column rationals degree span ur coefficients order)))
        (loop :for m :from 0 :to order
              :do (let* ((computed (aref out (+ offset (* m dimension) c))) (e (nth m exact)))
                    (incf (curve-record-numbers record))
                    (assert (basis-finite-p computed) () "~A: order ~D, coordinate ~D holds ~S." label m c computed)
                    (cond
                      ((> m degree)
                       (assert (and (zerop computed) (plusp (float-sign computed))) ()
                               "~A: order ~D, above the degree, holds ~S." label m computed))
                      (t
                       (let* ((weights (if (zerop m)
                                           (exact-basis-row rationals degree span ur 0)
                                           (exact-size-row rationals degree span ur m)))
                              (losses (if (zerop m)
                                          (make-list (1+ degree) :initial-element value-loss)
                                          (exact-floor-row rationals degree span m)))
                              (rounding (* gamma (reduce #'+ (mapcar #'* weights magnitudes))))
                              (bound (+ rounding (* (+ 1 gamma) (+ (reduce #'+ (mapcar #'* losses magnitudes))
                                                                  product-loss))))
                              (error (abs (- (rational computed) e))))
                         (assert (<= error bound) ()
                                 "~A: order ~D, coordinate ~D is ~S and exactly ~S: off by ~E, and the bound is ~E."
                                 label m c computed (float e 1d0) (float error 1d0) (float bound 1d0))
                         (cond ((> error rounding) (incf (curve-record-floored record)))
                               ((plusp rounding)
                                (setf (curve-record-ratio record)
                                      (max (curve-record-ratio record) (/ error rounding))))))))))))))

(defun curve-controls (count dimension &optional (shift 0))
  "Control points from the fixed sequence: of mixed sign, of sizes from 2^-20 to 2^20 times 2^SHIFT, and not round."
  (let ((found (make-array (* count dimension) :element-type 'double-float)))
    (dotimes (i (length found) found)
      (setf (aref found i)
            (coerce (* (- (basis-random 2001) 1000) 1/7 (expt 2 (+ shift (- (basis-random 41) 20)))) 'double-float)))))

(defun curve-check-knots (degree knots dimension record &optional (shift 0))
  "One knot vector at one degree and one dimension: every parameter the basis tests try, at every order to one above
the degree. Returns the number of parameters."
  (let* ((limit (1+ degree)) (width (1+ degree)) (handle (basis:make-basis degree knots limit))
         (rationals (map 'vector #'rational knots)) (count (basis:control-count handle))
         (controls (curve-controls count dimension shift)) (parameters (basis-parameters knots degree)))
    (dolist (u parameters)
      (loop :for order :from 0 :to limit
            :do (let* ((expected (basis-expectation knots degree u order))
                       (rows (basis-sentinel (* (1+ order) width))) (out (basis-sentinel (* (1+ order) dimension)))
                       (code (cc:evaluate-code handle controls dimension u order rows out))
                       (label (format nil "degree ~D, dimension ~D, knots ~S, parameter ~S, order ~D" degree dimension
                                      knots u order)))
                  (cond
                    ((integerp expected)
                     (assert (= 0 code) () "~A: refused with ~D." label code)
                     (assert (= expected (basis:latest-span handle)) () "~A: span ~D." label (basis:latest-span handle))
                     ;; The rows are the basis module's own output, bit for bit.
                     (let ((basis-rows (basis-sentinel (* (1+ order) width))))
                       (assert (= 0 (bc:evaluate-code handle u order basis-rows)))
                       (assert (same-bits-p rows basis-rows) () "~A: the rows differ from the basis module's." label))
                     (curve-compare label knots rationals degree dimension controls expected u order out 0 record))
                    (t
                     (assert (= code (ecase expected (:outside 1) (:non-finite 2) (:undefined 3))) ()
                             "~A: the status is ~D, and by the definition ~S." label code expected)
                     (assert (and (basis-untouched-p rows) (basis-untouched-p out)) () "~A: refused after writing."
                             label))))))
    (length parameters)))

(defun curve-family (record)
  "Knot vectors of every kind the basis tests use, short of the extremes, in one, two and three dimensions."
  (let ((vectors 0) (parameters 0) (jumps 0))
    (flet ((try (degree breaks multiplicities dimension)
             (let ((knots (basis-knots breaks multiplicities)))
               (when (= 0 (basis-knot-rule degree knots))
                 (incf vectors)
                 (when (some (lambda (m) (= m (1+ degree))) (butlast (rest multiplicities))) (incf jumps))
                 (incf parameters (curve-check-knots degree knots dimension record))))))
      (loop :for degree :from 1 :to 5
            :do (let ((dimension (1+ (mod degree 3))))
                  (try degree '(0 1 2 3) (list (1+ degree) 1 1 (1+ degree)) dimension)
                  (try degree '(0 1) (list (1+ degree) (1+ degree)) 2)
                  (try degree (loop :for i :from 0 :to (+ 3 (* 2 degree)) :collect (- (* i 3/7) 2))
                       (make-list (+ 4 (* 2 degree)) :initial-element 1) dimension)
                  (try degree (loop :for i :from 0 :to 4 :collect (+ 1000 (* i 1/10)))
                       (list (1+ degree) 1 1 1 (1+ degree)) 3)
                  (loop :for inside :from 1 :to (1+ degree)
                        :do (try degree '(0 1 2 3 4 5 6 7) (list (1+ degree) 1 1 inside 1 1 1 (1+ degree)) 2))
                  (dotimes (trial 3)
                    (let* ((count (+ 3 (basis-random 4)))
                           (breaks (let ((x (- (basis-random 5) 2)) (found '()))
                                     (dotimes (i count (nreverse found))
                                       (push x found)
                                       (incf x (* (1+ (basis-random 9)) (expt 2 (- (basis-random 41) 20)))))))
                           (multiplicities (loop :for i :from 0 :below count
                                                 :collect (if (or (= i 0) (= i (1- count)))
                                                              (1+ (basis-random (1+ degree)))
                                                              (1+ (basis-random degree))))))
                      (try degree breaks multiplicities dimension))))))
    (assert (plusp jumps) () "No knot vector with an interior knot where the basis jumps was admitted.")
    (values vectors parameters)))

(defun curve-underflow-tests ()
  "Control points so small that a weight times a coordinate is below the normal range, on ordinary knots: where the
underflow terms of the bound are what is being checked. The number of results that needed them is printed."
  (let ((record (make-curve-record)) (vectors 0))
    (let* ((large (expt 2d0 1023)) (handle (basis:make-basis 2 (doubles 0d0 0d0 0d0 1d0 1d0 1d0) 1))
           (controls (doubles large large large)) (out (basis-sentinel 2)) (rows (basis-sentinel 6))
           (parameters (doubles 0d0)) (tally (indices 0)))
      (assert (= 0 (cc:evaluate-code handle controls 1 0d0 1 rows out)))
      (assert (equalp out (doubles large 0d0)))
      (fill out 7777d0)
      (assert (= 0 (cc:batch-code handle controls 1 (doubles 1d0) 1 (indices 0) rows out)))
      (assert (equalp out (doubles large 0d0)))
      (assert (zerop (bytes-a-call (lambda (n) (cc:evaluate-loop handle controls 1 parameters 1 rows out tally n)) 20000))))
    (loop :for (degree breaks multiplicities dimension)
            :in '((1 (0 1 2) (2 1 2) 2) (2 (0 1 3 4) (3 1 1 3) 3) (3 (0 1/3 1) (4 1 4) 2) (2 (-2 0 1 5) (1 2 2 3) 1)
                  (3 (0 1 2 3 4 5 6 7) (1 1 1 1 1 1 1 1) 2))
          :do (let ((knots (basis-knots breaks (subseq multiplicities 0 (length breaks)))))
                (assert (= 0 (basis-knot-rule degree knots)) () "The fixture ~S is not a knot vector of degree ~D." knots
                        degree)
                (incf vectors)
                (curve-check-knots degree knots dimension record -1050)))
    (assert (plusp (curve-record-floored record)) () "No result of the underflow fixtures needed the underflow terms.")
    (format t "SPLINE-CURVE-UNDERFLOW-PASS knot-vectors=~D evaluations=~D numbers=~D needed-the-underflow-terms=~D~%" vectors
            (curve-record-evaluations record) (curve-record-numbers record) (curve-record-floored record))))

;;; ---- Refusals, and what they leave ----------------------------------------------------------

(defun curve-refusal-tests ()
  (let* ((knots (doubles 0d0 0d0 0d0 0d0 1d0 2d0 2d0 3d0 3d0 3d0 3d0)) (handle (basis:make-basis 3 knots 2))
         (dimension 2) (controls (curve-controls 7 dimension))
         (nan (- sb-ext:double-float-positive-infinity sb-ext:double-float-positive-infinity))
         (true-rows (basis-sentinel 12)))
    (assert (= 0 (bc:evaluate-code handle 0.5d0 2 true-rows)))
    (flet ((refused (code controls dimension parameter order rows-length out-length what &optional rows-written)
             (let ((rows (basis-sentinel rows-length)) (out (basis-sentinel out-length)))
               (assert (= code (cc:evaluate-code handle controls dimension parameter order rows out)) ()
                       "~A: status ~D, not ~D." what (cc:evaluate-code handle controls dimension parameter order rows out)
                       code)
               (assert (basis-untouched-p out) () "~A: refused after writing the result." what)
               (if rows-written
                   (assert (same-bits-p rows true-rows) () "~A: the rows are not the basis module's." what)
                   (assert (basis-untouched-p rows) () "~A: refused after writing the rows." what)))))
      (refused 4 controls 2 0.5d0 3 16 8 "an order above the basis's")
      (refused 5 (doubles) 0 0.5d0 2 12 0 "no dimension, with no control point and no result")
      (refused 5 controls 3 0.5d0 2 12 9 "a dimension the control points do not divide into")
      (refused 5 (curve-controls 6 2) 2 0.5d0 2 12 6 "a control point too few")
      (refused 5 (curve-controls 8 2) 2 0.5d0 2 12 6 "a control point too many")
      (refused 5 controls 2 0.5d0 2 12 5 "a result one short")
      (refused 5 controls 2 0.5d0 2 12 7 "a result one long")
      (refused 5 controls 2 0.5d0 2 11 6 "rows one short")
      (refused 1 controls 2 3.5d0 2 12 6 "a parameter above the domain")
      (refused 2 controls 2 nan 2 12 6 "a parameter that is not a number")
      (refused 3 controls 2 2d0 2 12 6 "a second derivative at a double knot of a cubic")
      ;; A control point of the span that is not finite: the parameter 0.5 is on span 3, which
      ;; uses control points 0 to 3. The rows are written; the result is not.
      (dolist (bad (list nan sb-ext:double-float-positive-infinity))
        (dolist (position '(0 3 7))
          (let ((spoiled (copy-seq controls)))
            (setf (aref spoiled position) bad)
            (refused 2 spoiled 2 0.5d0 2 12 6 "a control point of the span that is not finite" t))))
      ;; All equal would be a constant curve. Negating the first control
      ;; makes the first derivative at 1/2 equal to 3/2 times the largest double.
      (let ((huge (make-array 14 :element-type 'double-float :initial-element most-positive-double-float)))
        (setf (aref huge 0) (- most-positive-double-float))
        (assert (> (second (exact-curve-column (map 'vector #'rational knots) 3 3 1/2
                                               (loop :for j :below 4 :collect (rational (aref huge (* 2 j)))) 1))
                   (rational most-positive-double-float)))
        (refused 2 huge 2 0.5d0 2 12 6 "a result too large to hold" t)))
    ;; A control point that is not finite and is not of the span does not refuse the call.
    (let ((spoiled (copy-seq controls)) (rows (basis-sentinel 12)) (out (basis-sentinel 6)) (clean (basis-sentinel 6)))
      (setf (aref spoiled 8) nan (aref spoiled 13) sb-ext:double-float-negative-infinity)
      (assert (= 0 (cc:evaluate-code handle spoiled 2 0.5d0 2 rows out)))
      (assert (= 0 (cc:evaluate-code handle controls 2 0.5d0 2 rows clean)))
      (assert (same-bits-p out clean) () "A control point outside the span changed the result."))
    ;; An output that is an input, or the other output, is a typed error and nothing is written.
    (let ((view (basis:knots handle)))
      (flet ((aliased (controls dimension rows out what)
               (let ((before (list (copy-seq controls) (copy-seq rows) (copy-seq out))))
                 (assert (= 108 (cc:evaluate-code handle controls dimension 0.5d0 2 rows out)) ()
                         "~A: status ~D, not the typed error." what
                         (cc:evaluate-code handle controls dimension 0.5d0 2 rows out))
                 (assert (and (same-bits-p controls (first before)) (same-bits-p rows (second before))
                              (same-bits-p out (third before)))
                         () "~A: refused after writing." what))))
        (let ((shared (basis-sentinel 12)))
          (aliased controls 2 shared shared "rows and the result one array"))
        (let ((shared (curve-controls 7 2)))
          (aliased shared 2 (basis-sentinel 12) shared "the result and the control points one array")
          (aliased shared 2 shared (basis-sentinel 6) "the rows and the control points one array"))
        (aliased controls 2 view (basis-sentinel 6) "the rows the basis's own knots")
        (aliased controls 2 (basis-sentinel 12) view "the result the basis's own knots")
        (assert (same-bits-p knots view) () "A refused call wrote the basis's knots."))))
  (format t "SPLINE-CURVE-REFUSALS-PASS~%"))

;;; ---- Batches --------------------------------------------------------------------------------

(defun curve-batch-tests (record)
  (let* ((degree 3) (knots (doubles 0d0 0d0 0d0 0d0 0.3d0 1d0 1d0 2.5d0 4d0 4d0 4d0 4d0))
         (rationals (map 'vector #'rational knots)) (limit 2) (width 4) (dimension 3)
         (handle (basis:make-basis degree knots limit)) (controls (curve-controls 8 dimension))
         (good (doubles 3.9d0 0d0 0.3d0 0.3d0 4d0 2.5d0 0.7d0 1.0000000000000002d0 0.1d0))
         (count (length good)))
    ;; A batch is its single calls, bit for bit, in the rows, the spans and the result.
    (loop :for order :from 0 :to limit
          :do (let* ((parameters (if (= order 2) good (concatenate '(simple-array double-float (*)) good (doubles 1d0))))
                     (n (length parameters)) (per-rows (* (1+ order) width)) (per-out (* (1+ order) dimension))
                     (spans (make-array n :element-type '(unsigned-byte 62) :initial-element 99))
                     (rows (basis-sentinel (* n per-rows))) (out (basis-sentinel (* n per-out)))
                     (single-rows (basis-sentinel per-rows)) (single-out (basis-sentinel per-out)))
                (assert (= 0 (cc:batch-code handle controls dimension parameters order spans rows out)) ()
                        "A batch at order ~D was refused." order)
                (assert (= n (basis:refused-index handle)))
                (dotimes (i n)
                  (assert (= 0 (cc:evaluate-code handle controls dimension (aref parameters i) order single-rows single-out)))
                  (assert (= (aref spans i) (basis:latest-span handle)))
                  (assert (and (same-bits-p single-rows (subseq rows (* i per-rows) (* (1+ i) per-rows)))
                               (same-bits-p single-out (subseq out (* i per-out) (* (1+ i) per-out))))
                          () "Parameter ~D of the batch at order ~D differs from its single call." i order)
                  (curve-compare (format nil "batch parameter ~D, order ~D" i order) knots rationals degree dimension
                                 controls (aref spans i) (aref parameters i) order out (* i per-out) record))))
    (flet ((refused (code controls dimension parameters order span-count rows-length out-length index what
                     &optional rows-written)
             (let ((spans (make-array span-count :element-type '(unsigned-byte 62) :initial-element 99))
                   (rows (basis-sentinel rows-length)) (out (basis-sentinel out-length)))
               (assert (= code (cc:batch-code handle controls dimension parameters order spans rows out)) ()
                       "~A: status ~D." what (cc:batch-code handle controls dimension parameters order spans rows out))
               ;; The position is the basis's to report, and it reports one only where its own batch ran.
               (when index
                 (assert (= index (basis:refused-index handle)) () "~A: position ~D reported, not ~D." what
                         (basis:refused-index handle) index))
               (assert (basis-untouched-p out) () "~A: refused after writing the result." what)
               (unless rows-written
                 (assert (and (basis-untouched-p rows) (every (lambda (s) (= s 99)) spans)) ()
                         "~A: refused after writing the rows or the spans." what)))))
      ;; A parameter that cannot be evaluated refuses the whole batch with nothing written.
      (let ((parameters (copy-seq good)))
        (setf (aref parameters 4) 5d0 (aref parameters 7) -1d0)
        (refused 1 controls dimension parameters limit count (* count 12) (* count 9) 4 "a batch with a parameter outside"))
      (refused 4 controls dimension good 3 count (* count 16) (* count 12) nil "a batch above the basis's order")
      (refused 5 controls dimension good 2 count (* count 12) (1- (* count 9)) nil "a batch with a result one short")
      (refused 5 controls dimension good 2 count (1+ (* count 12)) (* count 9) nil "a batch with rows one long")
      (refused 5 controls dimension good 2 (1- count) (* count 12) (* count 9) nil "a batch with a span too few")
      (refused 5 controls 2 good 2 count (* count 12) (* count 6) nil "a batch whose dimension the control points do not divide into")
      (refused 5 (doubles) 0 good 2 count (* count 12) 0 nil "a batch with no dimension")
      ;; A control point that is not finite, used by a later parameter of the batch and not by its
      ;; first, which is on the last span: the rows and the spans are written, the result is not,
      ;; and no parameter is blamed.
      (let ((spoiled (copy-seq controls)))
        (setf (aref spoiled 0) sb-ext:double-float-positive-infinity)
        (refused 2 spoiled dimension good 2 count (* count 12) (* count 9) count
                 "a batch that uses a control point that is not finite" t)))
    ;; No parameter is a batch like any other.
    (assert (= 0 (cc:batch-code handle controls dimension (doubles) 2 (indices) (doubles) (doubles))))
    ;; An output of a batch that is its parameters, its control points or its other output.
    (let* ((spans (indices 0)) (shared (basis-sentinel 12)))
      (assert (= 108 (cc:batch-code handle controls dimension (doubles 0.5d0) 2 spans shared shared)))
      (assert (= 108 (cc:batch-code handle controls dimension (doubles) 2 (indices) (doubles) controls)))
      (assert (= 108 (cc:batch-code handle controls dimension (doubles 0.5d0) 2 spans (basis:knots handle) (basis-sentinel 9))))
      (let ((parameters (doubles 0.5d0 0.5d0 0.5d0 0.5d0 0.5d0 0.5d0 0.5d0 0.5d0 0.5d0)))
        (assert (= 108 (cc:batch-code handle controls dimension parameters 0 (indices 0 0 0 0 0 0 0 0 0) (basis-sentinel 36)
                                      parameters)))
        (assert (every (lambda (x) (= x 0.5d0)) parameters) () "A refused batch wrote its parameters."))))
  (format t "SPLINE-CURVE-BATCH-PASS~%"))

;;; ---- Allocation -----------------------------------------------------------------------------

(defun curve-allocation-tests ()
  (let* ((handle (basis:make-basis 3 (doubles 0d0 0d0 0d0 0d0 0.25d0 0.5d0 0.75d0 1d0 1d0 1d0 1d0) 2))
         (controls (curve-controls 7 2)) (parameters (doubles 0d0 0.1d0 0.25d0 0.6d0 0.99d0 1d0))
         (count (length parameters)) (rows (basis-sentinel 12)) (out (basis-sentinel 6))
         (batch-rows (basis-sentinel (* count 12))) (batch-out (basis-sentinel (* count 6)))
         (spans (make-array count :element-type '(unsigned-byte 62) :initial-element 0)) (tally (indices 0))
         (single (bytes-a-call (lambda (rounds) (cc:evaluate-loop handle controls 2 parameters 2 rows out tally rounds))
                               20000))
         (batched (bytes-a-call (lambda (rounds)
                                  (cc:batch-loop handle controls 2 parameters 2 spans batch-rows batch-out tally rounds))
                                20000)))
    (assert (= 0 single) () "A curve's evaluate! allocates ~D bytes for a round of ~D calls." single count)
    (assert (= 0 batched) () "A curve's evaluate-batch! allocates ~D bytes a call." batched)
    (assert (= 0 (aref tally 0)) () "~D calls of the measured loops did not succeed." (aref tally 0))
    (format t "SPLINE-CURVE-ALLOCATION-PASS evaluate=~D batch=~D bytes~%" single batched)))

;;; ---- The run --------------------------------------------------------------------------------

(defun run-spline-curve-tests ()
  (exact-curve-reference-tests)
  (curve-refusal-tests)
  (let ((record (make-curve-record)))
    (multiple-value-bind (vectors parameters) (curve-family record)
      (curve-batch-tests record)
      (assert (< 0 (curve-record-ratio record) 1) () "The worst error is ~E of its bound: zero, or beyond it."
              (float (curve-record-ratio record) 1d0))
      (format t "SPLINE-CURVE-PASS knot-vectors=~D parameters=~D evaluations=~D numbers=~D~%" vectors parameters
              (curve-record-evaluations record) (curve-record-numbers record))
      (format t "SPLINE-CURVE-BOUND worst-error=~,3F of its bound; numbers that needed the underflow terms: ~D~%"
              (float (curve-record-ratio record) 1d0) (curve-record-floored record))))
  (curve-underflow-tests)
  (curve-allocation-tests))
