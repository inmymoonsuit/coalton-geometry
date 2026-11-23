(in-package #:coalton-geometry/tests)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (sb-ext:add-package-local-nickname "BASIS" "COALTON-GEOMETRY/SPLINE/BASIS")
  (sb-ext:add-package-local-nickname "BC" "COALTON-GEOMETRY/TESTS/SPLINE-BASIS-CALLERS"))

;;; The B-spline basis against docs/spline-basis.md. Every number the module returns is compared
;;; with an exact one, computed in rationals by a route that shares nothing with the module's:
;;; no recurrence, a linear system from one polynomial identity. The tolerance is the contract's
;;; error bound and nothing looser. What a call should do with a parameter, which span, which
;;; refusal, is worked out here from the definitions, not asked of the module.

;;; ---- The exact reference ---------------------------------------------------------------------

(defun exact-solve (matrix right)
  "The solution in rationals of a square system, by elimination. MATRIX is a list of rows."
  (let* ((n (length matrix)) (a (make-array (list n (1+ n)))))
    (loop :for row :in matrix :for i :from 0
          :do (loop :for value :in row :for j :from 0 :do (setf (aref a i j) value))
              (setf (aref a i n) (nth i right)))
    (dotimes (c n)
      (let ((pivot (loop :for r :from c :below n :unless (zerop (aref a r c)) :return r)))
        (assert pivot () "The reference's system is singular.")
        (unless (= pivot c)
          (dotimes (j (1+ n)) (rotatef (aref a c j) (aref a pivot j))))
        (dotimes (r n)
          (unless (or (= r c) (zerop (aref a r c)))
            (let ((factor (/ (aref a r c) (aref a c c))))
              (loop :for j :from c :to n :do (decf (aref a r j) (* factor (aref a c j)))))))))
    (loop :for i :from 0 :below n :collect (/ (aref a i n) (aref a i i)))))

(defun exact-basis-row (knots degree span u order)
  "The derivatives of order ORDER at U, exactly, of the DEGREE + 1 basis functions of that degree that are not zero on
SPAN, the lowest-numbered first. KNOTS is a vector of rationals and U a rational.

The identity used: for u in the span, (y - u)^k is the sum over those functions j of N[j, k](u) times the product of
(y - knot[j + i]) for i from 1 to k. At k + 1 values of y that is a linear system for the values; its derivatives in
u give the derivatives the same way."
  (if (> order degree)
      (make-list (1+ degree) :initial-element 0)
      (let* ((nodes (loop :for i :from 0 :to degree :collect i))
             (matrix (loop :for y :in nodes
                           :collect (loop :for j :from (- span degree) :to span
                                          :collect (let ((product 1))
                                                     (loop :for i :from 1 :to degree
                                                           :do (setf product (* product (- y (aref knots (+ j i))))))
                                                     product))))
             (factor (let ((f (if (evenp order) 1 -1)))
                       (dotimes (i order f) (setf f (* f (- degree i))))))
             (right (loop :for y :in nodes :collect (* factor (expt (- y u) (- degree order))))))
        (exact-solve matrix right))))

(defun exact-size-row (knots degree span u order)
  "The contract's S for the derivative of order ORDER, at most DEGREE: what that derivative would be if the differences
that build it from the values of degree DEGREE - ORDER were sums."
  (let ((row (exact-basis-row knots (- degree order) span u 0)))
    (loop :for d :from (1+ (- degree order)) :to degree
          :do (setf row
                    (loop :for r :from 0 :to d
                          :collect (let ((j (+ (- span d) r)))
                                     (* d (+ (if (>= r 1)
                                                 (/ (nth (1- r) row) (- (aref knots (+ j d)) (aref knots j)))
                                                 0)
                                             (if (< r d)
                                                 (/ (nth r row) (- (aref knots (+ j d 1)) (aref knots (1+ j))))
                                                 0)))))))
    row))

(defun exact-floor-row (knots degree span order)
  "The contract's U for the derivative of order ORDER, at most DEGREE: what underflow can add to it. The values it is
built from can each be off by the values' own underflow term, and every quotient formed on the way by half the least
positive number; each step carries both on as it carries S."
  (let* ((k (- degree order))
         (row (make-list (1+ k) :initial-element (* (1+ k) (+ 2 k) (expt 2 -1074)))))
    (loop :for d :from (1+ k) :to degree
          :do (setf row
                    (loop :for r :from 0 :to d
                          :collect (let ((j (+ (- span d) r)))
                                     (* d (+ (if (>= r 1)
                                                 (/ (nth (1- r) row) (- (aref knots (+ j d)) (aref knots j)))
                                                 0)
                                             (if (< r d)
                                                 (/ (nth r row) (- (aref knots (+ j d 1)) (aref knots (1+ j))))
                                                 0)
                                             (expt 2 -1074)))))))
    row))

(defun exact-reference-tests ()
  "The reference itself, where the answer is known in closed form."
  (flet ((rationals (&rest knots) (coerce knots 'vector)))
    ;; A hat function: at a quarter of the way the two weights are 3/4 and 1/4.
    (assert (equal '(3/4 1/4) (exact-basis-row (rationals 0 0 1 1) 1 1 1/4 0)))
    (assert (equal '(-1 1) (exact-basis-row (rationals 0 0 1 1) 1 1 1/4 1)))
    ;; No interior knot: the four cubic Bernstein polynomials, and their derivatives.
    (let ((knots (rationals 0 0 0 0 1 1 1 1)) (u 1/4))
      (assert (equal (list (expt (- 1 u) 3) (* 3 u (expt (- 1 u) 2)) (* 3 u u (- 1 u)) (expt u 3))
                     (exact-basis-row knots 3 3 u 0)))
      (assert (equal (list (* -3 (expt (- 1 u) 2)) (- (* 3 (expt (- 1 u) 2)) (* 6 u (- 1 u)))
                           (- (* 6 u (- 1 u)) (* 3 u u)) (* 3 u u))
                     (exact-basis-row knots 3 3 u 1)))
      (assert (equal (list (* 6 (- 1 u)) (- (* 6 u) (* 12 (- 1 u))) (- (* 6 (- 1 u)) (* 12 u)) (* 6 u))
                     (exact-basis-row knots 3 3 u 2)))
      (assert (equal '(-6 18 -18 6) (exact-basis-row knots 3 3 u 3)))
      (assert (equal '(0 0 0 0) (exact-basis-row knots 3 3 u 4))))
    ;; Uniform quadratics at the middle of a span: 1/8, 3/4, 1/8, and slopes -1/2, 0, 1/2.
    (let ((knots (rationals 0 1 2 3 4 5 6)))
      (assert (equal '(1/8 3/4 1/8) (exact-basis-row knots 2 3 7/2 0)))
      (assert (equal '(-1/2 0 1/2) (exact-basis-row knots 2 3 7/2 1)))
      ;; At a knot of a uniform quadratic the two that meet are each a half.
      (assert (equal '(1/2 1/2 0) (exact-basis-row knots 2 3 3 0))))
    ;; S is the derivative with its differences made sums: for the hat, 1 and 1.
    (assert (equal '(1 1) (exact-size-row (rationals 0 0 1 1) 1 1 1/4 1)))
    (assert (equal '(27/16 45/16 21/16 3/16) (exact-size-row (rationals 0 0 0 0 1 1 1 1) 3 3 1/4 1))))
  (format t "SPLINE-BASIS-REFERENCE-PASS~%"))

;;; ---- What a call should do, from the definitions --------------------------------------------

(defun basis-finite-p (x)
  (and (= x x) (not (sb-ext:float-infinity-p x))))

(defun basis-knot-rule (degree knots)
  "The number of the first rule of the contract's table that a knot vector breaks, in the table's order, or 0."
  (let* ((count (length knots)) (width (1+ degree)))
    (cond
      ((< degree 1) 1)
      ((< count (+ 2 (* 2 degree))) 2)
      ((find-if-not #'basis-finite-p knots) 3)
      ((loop :for i :from 1 :below count :thereis (< (aref knots i) (aref knots (1- i)))) 4)
      ((loop :for knot :across knots :thereis (> (count knot knots :test #'=) width)) 5)
      ((= (aref knots degree) (aref knots (- count width))) 6)
      ;; A difference of doubles rounds to an infinity from most-positive plus half its last place.
      ((>= (- (rational (aref knots (1- count))) (rational (aref knots 0)))
           (+ (rational most-positive-double-float) (expt 2 970)))
       7)
      (t 0))))

(defun basis-expectation (knots degree u order)
  "What the contract says of a parameter: :non-finite, :outside, :undefined, or the number of its span."
  (let* ((n (- (length knots) degree 1)) (start (aref knots degree)) (end (aref knots n)))
    (cond
      ((not (basis-finite-p u)) :non-finite)
      ((or (< u start) (> u end)) :outside)
      ((and (< start u end) (find u knots :test #'=) (> (+ order (count u knots :test #'=)) degree)) :undefined)
      ((= u end) (loop :for s :from (1- n) :downto degree :when (< (aref knots s) (aref knots (1+ s))) :return s))
      (t (loop :for s :from degree :below n :when (and (<= (aref knots s) u) (< u (aref knots (1+ s)))) :return s)))))

(defun basis-gamma (k)
  "k u / (1 - k u), for the unit roundoff u = 2^-53."
  (let ((u (expt 2 -53))) (/ (* k u) (- 1 (* k u)))))

;;; ---- One evaluation against the reference ---------------------------------------------------

(defstruct basis-record
  (evaluations 0) (numbers 0) (value-ratio 0) (derivative-ratio 0) (weakness 0) (weak-at nil) (floored 0) (floored-values 0) (overflowed 0))

(defun basis-exact-rows (rationals degree span u limit)
  "The exact rows for orders 0 to LIMIT, and for orders 1 to the degree at most a pair for each row: its S and its U."
  (let ((exact (loop :for m :from 0 :to limit :collect (exact-basis-row rationals degree span (rational u) m)))
        (sizes (loop :for m :from 0 :to (min limit degree)
                     :collect (if (zerop m)
                                  nil
                                  (cons (exact-size-row rationals degree span (rational u) m)
                                        (exact-floor-row rationals degree span m))))))
    (values exact sizes)))

(defun basis-compare (label degree order out offset exact sizes record)
  "The block of (ORDER + 1)(DEGREE + 1) numbers at OFFSET of OUT against the exact rows, to the contract's bound."
  (let* ((width (1+ degree)) (gamma (basis-gamma (* 5 degree)))
         (underflow (* (1+ degree) (+ 2 degree) (expt 2 -1074))))
    (incf (basis-record-evaluations record))
    (loop :for m :from 0 :to order
          :do (let ((computed (loop :for r :from 0 :below width :collect (aref out (+ offset (* m width) r))))
                    (row (nth m exact)))
                (incf (basis-record-numbers record) width)
                (dolist (c computed)
                  (assert (basis-finite-p c) () "~A: order ~D holds ~S." label m c))
                (cond
                  ((zerop m)
                   (loop :for c :in computed :for e :in row
                         :do (let ((error (abs (- (rational c) e))))
                               (assert (<= error (+ (* gamma e) underflow)) ()
                                       "~A: a value is ~S and exactly ~S: off by ~E, and the bound is ~E." label c
                                       (float e 1d0) (float error 1d0) (float (+ (* gamma e) underflow) 1d0))
                               (assert (<= 0 (rational c) (+ 1 gamma)) () "~A: a value is ~S." label c)
                               ;; Measured against the part of the bound that rounding accounts for,
                               ;; where the error is within it; otherwise underflow was reached.
                               (cond
                                 ((> error (* gamma e)) (incf (basis-record-floored-values record)))
                                 ((plusp e)
                                  (setf (basis-record-value-ratio record)
                                        (max (basis-record-value-ratio record) (/ error (* gamma e))))))))
                   (assert (<= (abs (- (reduce #'+ computed :key #'rational) 1)) (+ gamma (* width underflow))) ()
                           "~A: the values sum to 1 + ~E." label
                           (float (- (reduce #'+ computed :key #'rational) 1) 1d0)))
                  ((> m degree)
                   (dolist (c computed)
                     (assert (and (zerop c) (plusp (float-sign c))) () "~A: order ~D, above the degree, holds ~S." label m c)))
                  (t
                   (let ((size (car (nth m sizes))) (floors (cdr (nth m sizes))))
                     (loop :for c :in computed :for e :in row :for s :in size :for f :in floors
                           :do (let ((error (abs (- (rational c) e))) (bound (+ (* gamma s) (* (+ 1 gamma) f))))
                                 (assert (<= error bound) ()
                                         "~A: a derivative of order ~D is ~S and exactly ~S: off by ~E, and the bound is ~E."
                                         label m c (float e 1d0) (float error 1d0) (float bound 1d0))
                                 ;; Where the error is within the part of the bound that rounding accounts
                                 ;; for, it is measured against that part; where it is not, underflow
                                 ;; was reached and the other part was needed.
                                 (cond
                                   ((> error (* gamma s)) (incf (basis-record-floored record)))
                                   ((plusp s)
                                    (setf (basis-record-derivative-ratio record)
                                          (max (basis-record-derivative-ratio record) (/ error (* gamma s))))))
                                 (when (and (/= 0 e) (> (/ s (abs e)) (basis-record-weakness record)))
                                   (setf (basis-record-weakness record) (/ s (abs e))
                                         (basis-record-weak-at record) label))))
                     (assert (<= (abs (reduce #'+ computed :key #'rational))
                                 (+ (* gamma (reduce #'+ size)) (* (+ 1 gamma) (reduce #'+ floors))))
                             () "~A: the derivatives of order ~D sum to ~E." label m
                             (float (reduce #'+ computed :key #'rational) 1d0)))))))))

(defun basis-sentinel (length)
  (make-array length :element-type 'double-float :initial-element 7777d0))

(defun basis-untouched-p (array)
  (every (lambda (x) (= x 7777d0)) array))

(defun basis-check-parameter (handle knots rationals degree u limit record)
  "Every order from 0 to LIMIT at one parameter: the status, the span, and every number."
  (let ((exact nil) (sizes nil) (width (1+ degree)))
    (loop :for order :from 0 :to limit
          :do (let* ((expected (basis-expectation knots degree u order))
                     (out (basis-sentinel (* (1+ order) width)))
                     (span-before (basis:latest-span handle))
                     (code (bc:evaluate-code handle u order out))
                     (label (format nil "degree ~D, knots ~S, parameter ~S, order ~D" degree knots u order)))
                (cond
                  ((and (integerp expected) (= code 2))
                   ;; Refused as too large to hold. That is right only where a term of a derivative
                   ;; asked for can reach the largest double: where S, with its rounding, can.
                   (unless exact
                     (multiple-value-setq (exact sizes) (basis-exact-rows rationals degree expected u limit)))
                   (let ((largest (loop :for m :from 1 :to (min order degree)
                                        :maximize (reduce #'max (car (nth m sizes))))))
                     (assert (and largest (>= (* (+ 1 (basis-gamma (* 5 degree))) largest)
                                              (rational most-positive-double-float)))
                             () "~A: refused as too large to hold, and no term of it is above ~E." label
                             (if largest (float largest 1d0) 0d0)))
                   (assert (basis-untouched-p out) () "~A: refused after writing." label)
                   (assert (= span-before (basis:latest-span handle)) () "~A: a refusal changed the latest span." label)
                   (incf (basis-record-overflowed record)))
                  ((integerp expected)
                   (assert (= 0 code) () "~A: refused with ~D." label code)
                   (assert (= expected (basis:latest-span handle)) () "~A: span ~D, and by the definition ~D." label
                           (basis:latest-span handle) expected)
                   (unless exact
                     (multiple-value-setq (exact sizes) (basis-exact-rows rationals degree expected u limit)))
                   (basis-compare label degree order out 0 exact sizes record))
                  (t
                   (assert (= code (ecase expected (:outside 1) (:non-finite 2) (:undefined 3))) ()
                           "~A: the status is ~D, and by the definition ~S." label code expected)
                   (assert (basis-untouched-p out) () "~A: refused after writing." label)
                   (assert (= span-before (basis:latest-span handle)) () "~A: a refusal changed the latest span." label)))))))

;;; ---- Knot vectors that try it ---------------------------------------------------------------

(defun basis-next (x direction)
  "The double next to X, above for a positive DIRECTION and below for a negative one."
  (cond
    ((zerop x) (* direction least-positive-double-float))
    ((minusp x) (- (basis-next (- x) (- direction))))
    (t (multiple-value-bind (significand exponent) (integer-decode-float x)
         (cond
           ((plusp direction) (scale-float (coerce (1+ significand) 'double-float) exponent))
           ((and (= significand (expt 2 52)) (> x least-positive-normalized-double-float))
            (scale-float (coerce (1- (* 2 significand)) 'double-float) (1- exponent)))
           (t (scale-float (coerce (1- significand) 'double-float) exponent)))))))

(defun basis-knots (breaks multiplicities)
  "A knot vector from its distinct values and how often each is repeated."
  (coerce (loop :for break :in breaks :for m :in multiplicities
                :append (make-list m :initial-element (coerce break 'double-float)))
          '(simple-array double-float (*))))

(defun basis-parameters (knots degree)
  "The parameters a knot vector is tried at: each knot of the domain, the doubles on each side of it, points inside
each span, both ends of the domain, and the doubles just outside them."
  (let* ((n (- (length knots) degree 1)) (start (aref knots degree)) (end (aref knots n)) (found '()))
    (loop :for s :from degree :to n
          :do (let ((knot (aref knots s)))
                (push knot found)
                (push (basis-next knot 1) found)
                (push (basis-next knot -1) found)
                (when (and (< s n) (< knot (aref knots (1+ s))))
                  (let ((next (aref knots (1+ s))))
                    (dolist (part '(1/2 1/3 7/8 1/1000))
                      (push (coerce (+ (rational knot) (* part (- (rational next) (rational knot)))) 'double-float)
                            found))))))
    (push (basis-next start -1) found)
    (push (basis-next end 1) found)
    (remove-duplicates found :test #'=)))

(defun basis-check-knots (degree knots record &key parameters)
  "One knot vector at one degree: made, read back, and tried at every parameter and every order to one above the
degree. Returns the number of parameters."
  (assert (= 0 (basis-knot-rule degree knots)) () "The fixture ~S is not a knot vector of degree ~D." knots degree)
  (let* ((limit (1+ degree)) (handle (basis:make-basis degree knots limit))
         (rationals (map 'vector #'rational knots))
         (parameters (or parameters (basis-parameters knots degree))))
    (assert (and (= degree (basis:degree handle)) (= (length knots) (basis:knot-count handle))
                 (= (- (length knots) degree 1) (basis:control-count handle)) (= limit (basis:highest-order handle))
                 (= (aref knots degree) (basis:domain-start handle))
                 (= (aref knots (- (length knots) degree 1)) (basis:domain-end handle))
                 (same-bits-p knots (basis:knots handle)) (not (eq knots (basis:knots handle))))
            () "A basis of degree ~D on ~S reads back wrongly." degree knots)
    (dolist (u parameters)
      (basis-check-parameter handle knots rationals degree u limit record))
    (length parameters)))

(defvar *basis-seed* 20261123)

(defun basis-random (limit)
  "A number from 0 below LIMIT, from a fixed sequence: the fixtures are the same on every run."
  (setf *basis-seed* (mod (+ (* *basis-seed* 6364136223846793005) 1442695040888963407) (expt 2 64)))
  (mod (ash *basis-seed* -33) limit))

(defun basis-family (record)
  "Clamped and unclamped, uniform and uneven, every multiplicity the contract permits inside and at the ends.
Returns the numbers of knot vectors and of parameters tried."
  (let ((vectors 0) (parameters 0) (kinds (make-hash-table :test #'equal)))
    (flet ((try (degree breaks multiplicities kind)
             (let ((knots (basis-knots breaks multiplicities)))
               (when (= 0 (basis-knot-rule degree knots))
                 (incf vectors)
                 (setf (gethash kind kinds) t)
                 (incf parameters (basis-check-knots degree knots record))))))
      (loop :for degree :from 1 :to 6
            :do ;; Clamped and uniform, with no interior knot and with several.
                (dolist (interior '(0 1 2 5))
                  (try degree (loop :for i :from 0 :to (1+ interior) :collect i)
                       (append (list (1+ degree)) (make-list interior :initial-element 1) (list (1+ degree)))
                       "clamped uniform"))
                ;; Unclamped and uniform: every knot simple, the domain strictly inside the knots.
                (try degree (loop :for i :from 0 :to (+ 3 (* 2 degree)) :collect i)
                     (make-list (+ 4 (* 2 degree)) :initial-element 1) "unclamped uniform")
                ;; Spacings that are not powers of two, away from the origin.
                (try degree (loop :for i :from 0 :to 4 :collect (+ 1000 (* i 1/10)))
                     (list (1+ degree) 1 1 1 (1+ degree)) "clamped, tenths, far from the origin")
                (try degree (loop :for i :from 0 :to (+ 3 (* 2 degree)) :collect (- (* i 3/7) 2))
                     (make-list (+ 4 (* 2 degree)) :initial-element 1) "unclamped, sevenths, across zero")
                ;; Every multiplicity inside, with every multiplicity at the two ends.
                (loop :for inside :from 1 :to (1+ degree)
                      :do (loop :for ends :from 1 :to (1+ degree)
                                :do (try degree '(0 1 2 3 4 5 6 7)
                                         (list ends 1 1 inside 1 1 1 ends)
                                         (if (= inside (1+ degree)) "an interior knot where the basis jumps"
                                             "interior and end multiplicities"))
                                    (try degree '(-3 -1 0 2 5)
                                         (list ends inside 1 inside ends) "two repeated interior knots")))
                ;; Wildly uneven: neighbouring spans differ by up to 2^60.
                (dotimes (trial 6)
                  (let* ((count (+ 3 (basis-random 4)))
                         (breaks (let ((x (- (basis-random 5) 2)) (found '()))
                                   (dotimes (i count (nreverse found))
                                     (push x found)
                                     (incf x (* (1+ (basis-random 9)) (expt 2 (- (basis-random 61) 30)))))))
                         (multiplicities (loop :for i :from 0 :below count
                                               :collect (if (or (= i 0) (= i (1- count)))
                                                            (1+ (basis-random (1+ degree)))
                                                            (1+ (basis-random degree))))))
                    (try degree breaks multiplicities "uneven")
                    (try degree breaks (append (list (1+ degree)) (make-list (- count 2) :initial-element 1)
                                               (list (1+ degree)))
                         "uneven and clamped")))))
    ;; The fixture's own premise: each kind was reached, and a jump inside was among them.
    (dolist (kind '("clamped uniform" "unclamped uniform" "clamped, tenths, far from the origin"
                    "unclamped, sevenths, across zero" "interior and end multiplicities"
                    "an interior knot where the basis jumps" "two repeated interior knots" "uneven" "uneven and clamped"))
      (assert (gethash kind kinds) () "No knot vector of the kind ~S was admitted." kind))
    (values vectors parameters)))

;;; ---- Refusals, and what they leave ----------------------------------------------------------

(defun basis-make-tests ()
  "Each rule of the contract's table, the number it carries, and the order the rules are asked in."
  (let ((nan (- sb-ext:double-float-positive-infinity sb-ext:double-float-positive-infinity))
        (infinity sb-ext:double-float-positive-infinity) (big most-positive-double-float))
    (loop :for (degree knots rule detail)
            :in `((0 ,(doubles 0d0 1d0) 1 0)
                  (2 ,(doubles 0d0 0d0 0d0 1d0 1d0) 2 5)
                  (1 ,(doubles) 2 0)
                  (1 ,(doubles 0d0 0d0 infinity infinity) 3 2)
                  (1 ,(doubles 0d0 nan 1d0 1d0) 3 1)
                  (1 ,(doubles 0d0 1d0 0.5d0 2d0) 4 2)
                  (1 ,(doubles 0d0 0d0 0d0 1d0 1d0) 5 0)
                  (2 ,(doubles 0d0 1d0 1d0 1d0 1d0 2d0 3d0) 5 1)
                  (1 ,(doubles 0d0 1d0 1d0 2d0) 6 1)
                  (2 ,(doubles 0d0 1d0 2d0 2d0 3d0 4d0) 6 2)
                  (1 ,(doubles (- big) 0d0 1d0 big) 7 3)
                  ;; Two rules broken at once: the earlier one in the table answers.
                  (1 ,(doubles 2d0 1d0 nan 0d0) 3 2)
                  (1 ,(doubles 1d0 0d0 0d0 0d0 0d0) 4 1)
                  ;; The most a knot may repeat, and a difference of the ends just short of too large.
                  (1 ,(doubles 0d0 0d0 1d0 1d0) 0 999)
                  (2 ,(doubles 0d0 0d0 0d0 1d0 1d0 1d0 2d0 2d0 2d0) 0 999)
                  (1 ,(doubles (- (/ big 2)) 0d0 1d0 (/ big 2)) 0 999))
          :do (assert (= rule (basis-knot-rule degree knots)) () "The fixture ~S breaks rule ~D, not ~D." knots
                      (basis-knot-rule degree knots) rule)
              (assert (= rule (bc:make-code degree knots 2)) () "Degree ~D on ~S: rule ~D, and the table says ~D." degree
                      knots (bc:make-code degree knots 2) rule)
              (assert (= detail (bc:make-detail degree knots 2)) () "Degree ~D on ~S: the refusal carries ~D, not ~D."
                      degree knots (bc:make-detail degree knots 2) detail)))
  ;; The handle holds its own copy: changing the caller's array afterwards changes nothing.
  (let* ((knots (doubles 0d0 0d0 0d0 1d0 2d0 2d0 2d0)) (handle (basis:make-basis 2 knots 1))
         (before (make-array 6 :element-type 'double-float)) (after (make-array 6 :element-type 'double-float)))
    (assert (= 0 (bc:evaluate-code handle 0.75d0 1 before)))
    (fill knots 5d0)
    (assert (= 0 (bc:evaluate-code handle 0.75d0 1 after)))
    (assert (same-bits-p before after) () "The basis followed a change to the caller's knots.")
    (assert (same-bits-p (doubles 0d0 0d0 0d0 1d0 2d0 2d0 2d0) (basis:knots handle))))
  (format t "SPLINE-BASIS-KNOT-RULES-PASS~%"))

(defun basis-refusal-tests ()
  (let* ((knots (doubles 0d0 0d0 0d0 0d0 1d0 2d0 2d0 3d0 3d0 3d0 3d0))
         (handle (basis:make-basis 3 knots 2))
         (nan (- sb-ext:double-float-positive-infinity sb-ext:double-float-positive-infinity)))
    (assert (= 0 (bc:evaluate-code handle 0.5d0 2 (basis-sentinel 12))))
    (assert (= 3 (basis:latest-span handle)))
    (flet ((refused (code parameter order length what)
             (let ((out (basis-sentinel length)))
               (assert (= code (bc:evaluate-code handle parameter order out)) () "~A: status ~D, not ~D." what
                       (bc:evaluate-code handle parameter order out) code)
               (assert (basis-untouched-p out) () "~A: refused after writing." what)
               (assert (= 3 (basis:latest-span handle)) () "~A: a refusal changed the latest span." what))))
      (refused 4 0.5d0 3 16 "an order above the handle's")
      (refused 5 0.5d0 2 11 "an output one short")
      (refused 5 0.5d0 2 13 "an output one long")
      (refused 5 0.5d0 1 12 "an output sized for another order")
      (refused 5 0.5d0 0 0 "an empty output")
      (refused 2 nan 2 12 "a parameter that is not a number")
      (refused 2 sb-ext:double-float-positive-infinity 2 12 "an infinite parameter")
      (refused 2 sb-ext:double-float-negative-infinity 0 4 "a parameter of minus infinity")
      (refused 1 -1d-300 2 12 "a parameter just below the domain")
      (refused 1 3.0000000000000004d0 2 12 "a parameter just above the domain")
      ;; The knot 2 is double: the first derivative exists there and the second does not.
      (refused 3 2d0 2 12 "a second derivative at a double knot of a cubic")
      ;; The order and the size are asked before the parameter.
      (refused 4 nan 3 16 "a bad order with a bad parameter")
      (refused 5 nan 2 11 "a bad size with a bad parameter"))
    (assert (= 0 (bc:evaluate-code handle 2d0 1 (basis-sentinel 8))))
    (assert (= 0 (bc:evaluate-code handle 1d0 2 (basis-sentinel 12))))
    ;; Minus zero is zero: it is the start of this domain, not below it.
    (assert (= 0 (bc:evaluate-code handle -0d0 2 (basis-sentinel 12))))
    (assert (= 3 (basis:latest-span handle)))
    ;; An output that is the basis's own knots is a typed error, whatever else is wrong, and the
    ;; knots are as they were.
    (let ((view (basis:knots handle)))
      (assert (= 108 (bc:evaluate-code handle 0.5d0 2 view)))
      (assert (= 108 (bc:evaluate-code handle nan 9 view)))
      (assert (= 108 (bc:batch-code handle (doubles 0.5d0) 2 (indices 0) view)))
      (assert (same-bits-p knots view) () "A refused call wrote the basis's knots.")
      ;; Read as parameters the view is only read.
      (let ((spans (make-array 11 :element-type '(unsigned-byte 62) :initial-element 0)))
        (assert (= 0 (bc:batch-code handle view 0 spans (basis-sentinel 44))))
        (assert (equalp spans (indices 3 3 3 3 4 6 6 6 6 6 6)) () "The spans of the knots themselves are ~S." spans))))
  ;; A derivative too large to hold. Between 0 and the least positive number the slope of a hat
  ;; function is the reciprocal of that number. The end of the domain is asked, where the
  ;; derivative is the one from inside: at the knot 0 itself a first derivative is refused.
  (let* ((tiny least-positive-double-float)
         (handle (basis:make-basis 1 (doubles -1d0 -1d0 0d0 tiny tiny) 1))
         (out (basis-sentinel 4)) (spans (indices 99 99)) (batch (basis-sentinel 8)))
    (assert (= 0 (bc:evaluate-code handle tiny 0 (basis-sentinel 2))))
    (assert (= 3 (bc:evaluate-code handle 0d0 1 out)))
    (assert (= 2 (bc:evaluate-code handle tiny 1 out)))
    (assert (basis-untouched-p out) () "A single call wrote before finding a derivative it could not hold.")
    (assert (= 2 (bc:batch-code handle (doubles -0.5d0 tiny) 1 spans batch)))
    (assert (= 1 (basis:refused-index handle)))
    (assert (= 2 (bc:batch-code handle (doubles tiny -0.5d0) 1 spans batch)))
    (assert (= 0 (basis:refused-index handle))))
  (format t "SPLINE-BASIS-REFUSALS-PASS~%"))

;;; ---- Batches --------------------------------------------------------------------------------

(defun basis-batch-tests (record)
  (let* ((degree 3) (knots (doubles 0d0 0d0 0d0 0d0 0.3d0 1d0 1d0 2.5d0 4d0 4d0 4d0 4d0))
         (rationals (map 'vector #'rational knots)) (limit 2) (width 4) (block (* (1+ limit) width))
         (handle (basis:make-basis degree knots limit))
         ;; Not sorted, with repeats, both ends, a simple knot and a double one.
         (good (doubles 3.9d0 0d0 0.3d0 0.3d0 4d0 2.5d0 0.7d0 1.0000000000000002d0 0.1d0))
         (count (length good)))
    ;; A batch is its single calls, bit for bit, at every order the double knot allows.
    (loop :for order :from 0 :to limit
          :do (let* ((parameters (if (= order 2) good (concatenate '(simple-array double-float (*)) good (doubles 1d0))))
                     (n (length parameters)) (per (* (1+ order) width))
                     (spans (make-array n :element-type '(unsigned-byte 62) :initial-element 99))
                     (out (basis-sentinel (* n per))) (single (basis-sentinel per)))
                (assert (= 0 (bc:batch-code handle parameters order spans out)) () "A batch at order ~D was refused." order)
                (assert (= n (basis:refused-index handle)))
                (dotimes (i n)
                  (assert (= 0 (bc:evaluate-code handle (aref parameters i) order single)))
                  (assert (= (aref spans i) (basis:latest-span handle) (basis-expectation knots degree (aref parameters i) order))
                          () "Parameter ~D of the batch has span ~D." i (aref spans i))
                  (assert (same-bits-p single (subseq out (* i per) (* (1+ i) per))) ()
                          "Parameter ~D of the batch at order ~D differs from its single call." i order)
                  (multiple-value-bind (exact sizes) (basis-exact-rows rationals degree (aref spans i) (aref parameters i) order)
                    (basis-compare (format nil "batch parameter ~D, order ~D" i order) degree order out (* i per) exact sizes
                                   record)))))
    ;; One parameter that cannot be evaluated refuses the whole batch before anything is written,
    ;; and the first such is the one reported.
    (loop :for (bad code what) :in `((5d0 1 "outside the domain")
                                     (,sb-ext:double-float-positive-infinity 2 "not finite")
                                     (1d0 3 "at a double knot, for a second derivative"))
          :do (loop :for position :in (list 0 4 (1- count))
                    :do (let ((parameters (copy-seq good)) (spans (make-array count :element-type '(unsigned-byte 62)
                                                                                    :initial-element 99))
                              (out (basis-sentinel (* count block))))
                          (setf (aref parameters position) bad)
                          (when (< position 6) (setf (aref parameters 6) -7d0))
                          (assert (= code (bc:batch-code handle parameters limit spans out)) ()
                                  "A batch with a parameter ~A at ~D: status ~D." what position
                                  (bc:batch-code handle parameters limit spans out))
                          (assert (= position (basis:refused-index handle)) ()
                                  "A batch with a parameter ~A at ~D reports position ~D." what position
                                  (basis:refused-index handle))
                          (assert (and (basis-untouched-p out) (every (lambda (s) (= s 99)) spans)) ()
                                  "A batch with a parameter ~A at ~D was refused after writing." what position))))
    ;; Sizes and the order, each refused with nothing written and no parameter blamed.
    (flet ((refused (code parameters order span-count out-length what)
             (let ((spans (make-array span-count :element-type '(unsigned-byte 62) :initial-element 99))
                   (out (basis-sentinel out-length)))
               (assert (= code (bc:batch-code handle parameters order spans out)) () "~A: status ~D." what
                       (bc:batch-code handle parameters order spans out))
               (assert (= (length parameters) (basis:refused-index handle)) () "~A: a parameter was blamed." what)
               (assert (and (basis-untouched-p out) (every (lambda (s) (= s 99)) spans)) () "~A: refused after writing." what))))
      (refused 4 good 3 count (* count 16) "a batch at an order above the handle's")
      (refused 5 good 2 (1- count) (* count block) "a batch with too few spans")
      (refused 5 good 2 (1+ count) (* count block) "a batch with too many spans")
      (refused 5 good 2 count (1- (* count block)) "a batch with an output one short")
      (refused 5 good 2 count (* count width) "a batch with an output sized for values only")
      (refused 5 (doubles) 2 0 block "an empty batch with an output")
      (refused 5 (doubles) 2 1 0 "an empty batch with a span"))
    ;; No parameter is a batch like any other: it succeeds and writes nothing.
    (assert (= 0 (bc:batch-code handle (doubles) 2 (indices) (doubles))))
    (assert (= 0 (basis:refused-index handle))))
  (format t "SPLINE-BASIS-BATCH-PASS~%"))

;;; ---- Where underflow is reached -------------------------------------------------------------

(defun basis-underflow-tests ()
  "Knot vectors whose spans differ by more than a quotient of them can keep, tried at the same parameters as every
other. They are held to the same bounds: this is where the underflow terms of both are what is being checked, and
the number of derivatives that needed theirs is printed."
  (let ((record (make-basis-record)) (vectors 0))
    ;; The degree-one intermediate 1/h overflows; after division by a wide
    ;; knot interval every requested second derivative (and its S) fits.
    (let* ((h (expt 2d0 -1030)) (u (/ h 2))
           (knots (doubles -1024d0 -1024d0 -1024d0 0d0 h 1024d0 1024d0 1024d0))
           (handle (basis:make-basis 2 knots 2)) (parameters (doubles u)) (out (basis-sentinel 9))
           (tally (indices 0)))
      (basis-check-parameter handle knots (map 'vector #'rational knots) 2 u 2 record)
      (assert (zerop (bytes-a-call (lambda (n) (bc:evaluate-loop handle parameters 2 out tally n)) 20000))))
    (loop :for (degree multiplicities exponents)
            :in '((1 (2 1 1 2) (-1000 0 0))
                  (2 (3 1 1 3) (-1040 -520 0))
                  (3 (4 1 1 4) (-1060 -530 0))
                  (3 (4 1 1 1 4) (-700 0 -700 0))
                  (2 (1 1 1 1 1 1 1) (-1000 -500 0 500 600 700))
                  (3 (4 2 1 3 4) (-1074 -1074 -1073 -1070)))
          :do (let* ((breaks (let ((x 0) (found (list 0)))
                               (dolist (e exponents (nreverse found))
                                 (incf x (expt 2 e))
                                 (push x found))))
                     (knots (basis-knots breaks multiplicities)))
                (assert (and (= (length breaks) (length multiplicities)) (= 0 (basis-knot-rule degree knots))) ()
                        "The fixture ~S is not a knot vector of degree ~D." knots degree)
                (incf vectors)
                (basis-check-knots degree knots record)))
    ;; The premise: some derivative was off by more than rounding accounts for, so the term for
    ;; underflow was what admitted it.
    (assert (plusp (basis-record-floored record)) () "No derivative of the underflow fixtures needed the underflow term.")
    (assert (plusp (basis-record-overflowed record)) () "No derivative of the underflow fixtures was too large to hold.")
    (format t "SPLINE-BASIS-EXTREMES-PASS knot-vectors=~D evaluations=~D numbers=~D needed-the-underflow-term: values=~D derivatives=~D; calls refused as too large to hold=~D~%"
            vectors (basis-record-evaluations record) (basis-record-numbers record) (basis-record-floored-values record)
            (basis-record-floored record) (basis-record-overflowed record))))

;;; ---- Allocation -----------------------------------------------------------------------------

(defun basis-allocation-tests ()
  (let* ((handle (basis:make-basis 3 (doubles 0d0 0d0 0d0 0d0 0.25d0 0.5d0 0.75d0 1d0 1d0 1d0 1d0) 2))
         (parameters (doubles 0d0 0.1d0 0.25d0 0.6d0 0.99d0 1d0)) (count (length parameters))
         (out (basis-sentinel 12)) (batch (basis-sentinel (* count 12)))
         (spans (make-array count :element-type '(unsigned-byte 62) :initial-element 0)) (tally (indices 0))
         (single (bytes-a-call (lambda (rounds) (bc:evaluate-loop handle parameters 2 out tally rounds)) 20000))
         (batched (bytes-a-call (lambda (rounds) (bc:batch-loop handle parameters 2 spans batch tally rounds)) 20000))
         ;; A refusal allocates nothing either: the same loops with a parameter outside the domain.
         (bad (doubles 0.5d0 2d0))
         (refused (bytes-a-call (lambda (rounds) (bc:evaluate-loop handle bad 2 out tally rounds)) 20000)))
    (assert (= 0 single) () "evaluate! allocates ~D bytes for a round of ~D calls." single count)
    (assert (= 0 batched) () "evaluate-batch! allocates ~D bytes a call." batched)
    (assert (= 0 refused) () "A refused evaluate! allocates ~D bytes for two calls." refused)
    ;; The loops ran what they were meant to: only the calls outside the domain did not succeed.
    (assert (= 21000 (aref tally 0)) () "~D calls of the measured loops did not succeed, and 21000 were meant not to."
            (aref tally 0))
    (format t "SPLINE-BASIS-ALLOCATION-PASS evaluate=~D batch=~D refused=~D bytes~%" single batched refused)))

;;; ---- The run --------------------------------------------------------------------------------

(defun run-spline-basis-tests ()
  (let ((traps (getf (sb-int:get-floating-point-modes) :traps)))
    (dolist (kind '(:overflow :invalid :divide-by-zero))
      (assert (not (member kind traps)) ()
              "The contract's arithmetic is IEEE with traps off, as the pinned Coalton leaves them; ~S is on." kind)))
  (exact-reference-tests)
  (basis-make-tests)
  (basis-refusal-tests)
  (let ((record (make-basis-record)))
    (multiple-value-bind (vectors parameters) (basis-family record)
      (basis-batch-tests record)
      (assert (and (< 0 (basis-record-value-ratio record) 1) (< 0 (basis-record-derivative-ratio record) 1)) ()
              "The worst errors are ~E and ~E of their bounds: one is zero or beyond it."
              (float (basis-record-value-ratio record) 1d0) (float (basis-record-derivative-ratio record) 1d0))
      (format t "SPLINE-BASIS-PASS knot-vectors=~D parameters=~D evaluations=~D numbers=~D~%" vectors parameters
              (basis-record-evaluations record) (basis-record-numbers record))
      (format t "SPLINE-BASIS-BOUND worst-value-error=~,3F of its bound, worst-derivative-error=~,3F of its bound~%"
              (float (basis-record-value-ratio record) 1d0) (float (basis-record-derivative-ratio record) 1d0))
      ;; As a power of two: the ratio itself can be beyond what a double holds.
      (format t "SPLINE-BASIS-WEAKEST S is at most 2^~D times the derivative it bounds, at ~A~%"
              (integer-length (floor (basis-record-weakness record))) (basis-record-weak-at record))
      (format t "SPLINE-BASIS-FLOORED in the ordinary families: numbers that needed the underflow term, values ~D and derivatives ~D; calls refused as too large to hold, ~D~%"
              (basis-record-floored-values record) (basis-record-floored record) (basis-record-overflowed record))))
  (basis-underflow-tests)
  (basis-allocation-tests))
