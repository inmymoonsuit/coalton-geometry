(in-package #:coalton-geometry/tests)

;;; The exact reference for the nearest-parameter search of docs/spline-nearest.md, by a route
;;; that shares nothing with the module's: no bound over an interval, no halving, no Newton.
;;; On each span a curve is a polynomial with rational coefficients, so the residual
;;; (C(t) - X) . C'(t) is one too; its real roots are counted and isolated exactly by a Sturm
;;; chain in rationals. Every least point of the distance is then known to any precision.
;;;
;;; A polynomial is a list of rational coefficients, the constant first.

(defun poly-trim (p)
  (let ((end (position-if-not #'zerop p :from-end t)))
    (if end (subseq p 0 (1+ end)) '())))

(defun poly-value (p x)
  (let ((value 0))
    (dolist (c (reverse p) value)
      (setf value (+ (* value x) c)))))

(defun poly-add (p q)
  (poly-trim (loop :for i :from 0 :below (max (length p) (length q))
                   :collect (+ (or (nth i p) 0) (or (nth i q) 0)))))

(defun poly-scale (p k)
  (poly-trim (mapcar (lambda (c) (* k c)) p)))

(defun poly-multiply (p q)
  (if (or (null p) (null q))
      '()
      (let ((product (make-list (1- (+ (length p) (length q))) :initial-element 0)))
        (loop :for a :in p :for i :from 0
              :do (loop :for b :in q :for j :from 0 :do (incf (nth (+ i j) product) (* a b))))
        (poly-trim product))))

(defun poly-derivative (p)
  (poly-trim (loop :for c :in (rest p) :for k :from 1 :collect (* k c))))

(defun poly-remainder (p q)
  "The remainder of P on division by Q, which is not zero."
  (let ((r (poly-trim p)) (dq (1- (length q))) (lead (car (last q))))
    (loop :while (and r (>= (1- (length r)) dq))
          :do (let* ((shift (- (1- (length r)) dq)) (factor (/ (car (last r)) lead)))
                (setf r (poly-trim (loop :for c :in r :for i :from 0
                                         :collect (if (>= i shift) (- c (* factor (nth (- i shift) q))) c))))))
    r))

(defun poly-quotient (p q)
  "The quotient of P on division by Q, which divides it."
  (let ((r (poly-trim p)) (dq (1- (length q))) (lead (car (last q))) (found '()))
    (loop :while (and r (>= (1- (length r)) dq))
          :do (let* ((shift (- (1- (length r)) dq)) (factor (/ (car (last r)) lead)))
                (push (cons shift factor) found)
                (setf r (poly-trim (loop :for c :in r :for i :from 0
                                         :collect (if (>= i shift) (- c (* factor (nth (- i shift) q))) c))))))
    (assert (null r) () "The division of the reference is not exact.")
    (let ((quotient (make-list (1+ (reduce #'max found :key #'car :initial-value 0)) :initial-element 0)))
      (dolist (term found (poly-trim quotient))
        (setf (nth (car term) quotient) (cdr term))))))

(defun poly-sturm (p)
  "The Sturm chain of the polynomial with the roots of P, each once: P is first divided by what it shares with its
derivative."
  (let ((chain (list (poly-derivative p) p)))
    (loop :for r := (poly-remainder (second chain) (first chain))
          :while r
          :do (push (poly-scale r -1) chain))
    ;; The last of the chain is what P shares with its derivative. Dividing P by it leaves every root once.
    (let* ((shared (first chain))
           (simple (if (> (length shared) 1) (poly-quotient p shared) p))
           (again (list (poly-derivative simple) simple)))
      (loop :for r := (and (first again) (poly-remainder (second again) (first again)))
            :while r
            :do (push (poly-scale r -1) again))
      (reverse (remove nil again)))))

(defun poly-variations (chain x)
  (let ((signs (remove 0 (mapcar (lambda (q) (signum (poly-value q x))) chain))))
    (loop :for (a b) :on signs :while b :count (/= a b))))

(defun poly-roots (p low high width)
  "Every real root of P in the closed interval from LOW to HIGH, each as an interval (a . b) no wider than WIDTH
that holds it and no other, in increasing order. A root that is a rational endpoint of a halving is returned as
(a . a). P is not the zero polynomial."
  (let ((p (poly-trim p)))
    (assert p () "The reference was asked for the roots of the zero polynomial.")
    (if (= 1 (length p))
        '()
        (let ((chain (poly-sturm p)) (simple nil) (found '()))
          (setf simple (first chain))
          (labels ((count-in (a b) (- (poly-variations chain a) (poly-variations chain b)))  ; roots in (a, b]
                   (isolate (a b)
                     ;; Roots of (a, b], b not itself a root.
                     (let ((n (count-in a b)))
                       (cond
                         ((zerop n))
                         ((and (= n 1) (<= (- b a) width)) (push (cons a b) found))
                         (t (let ((m (/ (+ a b) 2)))
                              (cond
                                ((zerop (poly-value simple m))
                                 ;; The middle is a root exactly: step off it by less than the nearest other root.
                                 (let ((e (/ (- b a) 4)))
                                   (loop :until (and (= 1 (count-in (- m e) (+ m e)))
                                                     (not (zerop (poly-value simple (- m e))))
                                                     (not (zerop (poly-value simple (+ m e)))))
                                         :do (setf e (/ e 2)))
                                   (isolate a (- m e))
                                   (push (cons m m) found)
                                   (isolate (+ m e) b)))
                                (t (isolate a m) (isolate m b)))))))))
            (when (zerop (poly-value simple low)) (push (cons low low) found))
            (cond
              ((zerop (poly-value simple high))
               ;; Step in from the high end, which is a root, by less than the nearest other root.
               (let ((e (/ (- high low) 4)))
                 (loop :until (and (not (zerop (poly-value simple (- high e))))
                                   (= 1 (count-in (- high e) high)))
                       :do (setf e (/ e 2)))
                 (isolate low (- high e))
                 (push (cons high high) found)))
              (t (isolate low high))))
          (sort (remove-duplicates found :test #'equal) #'< :key #'car)))))

(defun exact-span-polynomials (knots degree span controls dimension)
  "For each coordinate, the polynomial that the curve is on SPAN, by interpolating DEGREE + 1 exact points of it.
KNOTS is a vector of rationals and CONTROLS a vector of rationals, a point after a point."
  (let* ((low (aref knots span)) (high (aref knots (1+ span)))
         (nodes (loop :for i :from 0 :to degree :collect (+ low (* (- high low) (/ i (max degree 1))))))
         (matrix (loop :for x :in nodes :collect (loop :for k :from 0 :to degree :collect (expt x k)))))
    (loop :for c :from 0 :below dimension
          :collect (let ((coefficients (loop :for j :from (- span degree) :to span
                                             :collect (aref controls (+ (* j dimension) c)))))
                     (poly-trim (exact-solve matrix (loop :for x :in nodes
                                                          :collect (exact-combination knots degree span x
                                                                                      coefficients))))))))

(defun exact-least-points (knots degree controls dimension point &optional (width (expt 2 -200)))
  "Every least point of the distance from POINT to the curve: a list of (parameter squared-distance kind), kind one
of :foot, :start and :end, in increasing order of the parameter. A foot's parameter is the middle of an interval no
wider than WIDTH that holds it, and its squared distance is the exact one at that middle. Feet where the distance
has a greatest value, or only a level point, are not least points and are left out.

Also returns, as a second value, whether the residual vanishes identically on some span: the point is then
equally far from a whole piece of the curve, and no list of least points describes it."
  (let* ((n (- (length knots) degree 1)) (start (aref knots degree)) (end (aref knots n)) (found '()) (flat nil))
    (flet ((squared (span parameter)
             (loop :for c :from 0 :below dimension
                   :sum (expt (- (exact-combination knots degree span parameter
                                                    (loop :for j :from (- span degree) :to span
                                                          :collect (aref controls (+ (* j dimension) c))))
                                 (aref point c))
                              2))))
      (loop :for span :from degree :below n
            :when (< (aref knots span) (aref knots (1+ span)))
              :do (let* ((low (aref knots span)) (high (aref knots (1+ span)))
                         (curves (exact-span-polynomials knots degree span controls dimension))
                         (residual (let ((sum '()))
                                     (loop :for curve :in curves :for c :from 0
                                           :do (setf sum (poly-add sum (poly-multiply
                                                                        (poly-add curve (list (- (aref point c))))
                                                                        (poly-derivative curve)))))
                                     sum)))
                    (cond
                      ((null residual) (setf flat t))
                      (t
                       (dolist (root (poly-roots residual low high (* width (- high low))))
                         (let* ((a (car root)) (b (cdr root)) (middle (/ (+ a b) 2)))
                           ;; A least point: the residual goes from below zero to above it. At a root that is
                           ;; a knot the two sides are judged on their own spans, so a knot is taken on the
                           ;; span to its right and the sign before it from the span to its left, below.
                           (unless (or (= middle low) (= middle high))
                             (let ((before (poly-value residual (if (= a b) (- a (* width (- high low))) a)))
                                   (after (poly-value residual (if (= a b) (+ b (* width (- high low))) b))))
                               (when (and (minusp before) (plusp after))
                                 (push (list middle (squared span middle) :foot) found))))))
                       ;; The ends of the domain, and a knot where the residual passes through zero.
                       (when (and (= low start) (not (minusp (poly-value residual low))))
                         (when (or (plusp (poly-value residual low))
                                   (plusp (poly-value residual (+ low (* width (- high low))))))
                           (push (list low (squared span low) :start) found)))
                       (when (and (= high end) (not (plusp (poly-value residual high))))
                         (when (or (minusp (poly-value residual high))
                                   (minusp (poly-value residual (- high (* width (- high low))))))
                           (push (list high (squared span high) :end) found)))
                       (when (and (< high end) (zerop (poly-value residual high))
                                  (minusp (poly-value residual (- high (* width (- high low))))))
                         ;; A foot exactly at an interior knot: least if the residual rises out of it on
                         ;; the next span too. The curve is smooth there, so the residual is zero from both.
                         (let ((next (loop :for s :from (1+ span) :below n
                                           :when (< (aref knots s) (aref knots (1+ s))) :return s)))
                           (let* ((curves (exact-span-polynomials knots degree next controls dimension))
                                  (beyond (let ((sum '()))
                                            (loop :for curve :in curves :for c :from 0
                                                  :do (setf sum (poly-add sum (poly-multiply
                                                                               (poly-add curve (list (- (aref point c))))
                                                                               (poly-derivative curve)))))
                                            sum)))
                             (when (and beyond
                                        (plusp (poly-value beyond (+ high (* width (- (aref knots (1+ next)) high))))))
                               (push (list high (squared span high) :foot) found)))))))))
      (values (sort found #'< :key #'first) flat))))

(defun exact-nearest-reference-tests ()
  "The reference itself, where the answer is known."
  ;; Roots: a cubic with three known roots, one of them an endpoint of a halving and one double.
  (flet ((holds (interval root) (and (<= (car interval) root (cdr interval)))))
    (let ((roots (poly-roots (poly-multiply (poly-multiply '(-1/3 1) '(-1/2 1)) '(-7/5 1)) 0 2 (expt 2 -60))))
      (assert (and (= 3 (length roots)) (holds (first roots) 1/3) (holds (second roots) 1/2) (holds (third roots) 7/5))
              () "The roots found are ~S." roots)
      (assert (every (lambda (interval) (<= (- (cdr interval) (car interval)) (expt 2 -60))) roots)))
    (let ((roots (poly-roots (poly-multiply (poly-multiply '(-1 1) '(-1 1)) '(-3/2 1)) 0 2 (expt 2 -40))))
      (assert (and (= 2 (length roots)) (holds (first roots) 1) (holds (second roots) 3/2)) ()
              "With a double root the roots found are ~S." roots))
    (assert (equal '((0 . 0) (2 . 2)) (poly-roots (poly-multiply '(0 1) '(-2 1)) 0 2 (expt 2 -40))))
    (assert (null (poly-roots '(1 0 1) -5 5 1/8))))
  ;; A parabola: the curve (u, u^2) on [0, 1] as a quadratic with no interior knot, control
  ;; points (0, 0), (1/2, 0), (1, 1). From (0, 1/2) the residual is 2 u^3, with one foot at u = 0,
  ;; which is the start of the domain; the distance rises from it, so the least point is the start.
  (let ((knots (vector 0 0 0 1 1 1)) (controls (vector 0 0 1/2 0 1 1)))
    (assert (equal '((0 1/4 :start)) (exact-least-points knots 2 controls 2 (vector 0 1/2))))
    ;; From (0, 3/2) the residual is 2 u^3 - 2 u: a greatest value of the distance at u = 0, which is
    ;; not a least point, and a least point at the end, u = 1, where the residual is zero.
    (assert (equal '((1 5/4 :end)) (exact-least-points knots 2 controls 2 (vector 0 3/2))))
    ;; From (1, 3/2), straight above the end: the residual is below zero all the way, and the end is
    ;; the least point without being a foot.
    (assert (equal '((1 1/4 :end)) (exact-least-points knots 2 controls 2 (vector 1 3/2))))
    ;; From (3/4, 0): one interior foot. u^2 less than it by the residual 2 u^3 + u - 3/4 = 0, whose
    ;; root is 1/2. The squared distance there is 1/16 + 1/16.
    (let ((least (exact-least-points knots 2 controls 2 (vector 3/4 0))))
      (assert (and (= 1 (length least)) (eq :foot (third (first least)))
                   (< (abs (- (first (first least)) 1/2)) (expt 2 -190))
                   (< (abs (- (second (first least)) 1/8)) (expt 2 -180)))
              () "The least points found are ~S." least))
    ;; From outside the start along the tangent: the start, and nothing else.
    (assert (equal '((0 1 :start)) (exact-least-points knots 2 controls 2 (vector -1 0)))))
  ;; A closed loop of straight sides would not be smooth, so two feet are made with a curve that
  ;; bends back: a cubic through (0, 0), up and back down to (2, 0), seen from above its middle.
  (let* ((knots (vector 0 0 0 0 1 1 1 1)) (controls (vector 0 0 0 3 2 3 2 0))
         (least (exact-least-points knots 3 controls 2 (vector 1 4))))
    ;; By the symmetry of the curve about x = 1 the top, at u = 1/2, is a foot; the distance there is
    ;; 4 - 9/4 = 7/4.
    (assert (find-if (lambda (entry) (and (eq :foot (third entry)) (< (abs (- (first entry) 1/2)) (expt 2 -190))
                                          (< (abs (- (second entry) 49/16)) (expt 2 -180))))
                     least)
            () "The least points found are ~S." least))
  ;; A point equally far from a whole curve: every point of a curve that is a single point.
  (multiple-value-bind (least flat) (exact-least-points (vector 0 0 0 1 1 1) 2 (vector 1 1 1 1 1 1) 2 (vector 0 0))
    (assert (and (null least) flat)))
  (format t "SPLINE-NEAREST-REFERENCE-PASS~%"))
