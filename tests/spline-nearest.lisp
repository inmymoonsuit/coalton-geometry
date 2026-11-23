(in-package #:coalton-geometry/tests)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (sb-ext:add-package-local-nickname "NEAREST" "COALTON-GEOMETRY/SPLINE/NEAREST")
  (sb-ext:add-package-local-nickname "NC" "COALTON-GEOMETRY/TESTS/SPLINE-NEAREST-CALLERS"))

;;; The nearest-parameter search against docs/spline-nearest.md. What a point's answer should be
;;; is taken from the exact reference of spline-nearest-reference.lisp, which finds every least
;;; point of the distance by isolating the roots of a polynomial in rationals and shares nothing
;;; with the module's bounds. The four promises of the contract are then checked as they are
;;; written: that a foot is a foot, that it is the nearest of the whole curve, that a second
;;; answer is never hidden, and that a hint changes none of it.

(defstruct nearest-record (points 0) (feet 0) (ends 0) (tied 0) (unresolved 0) (by-bracket 0) (by-residual 0))

(defvar *nearest-exact* (make-hash-table :test #'equalp)
  "The exact least points of each problem met, so that the same problem with another hint is not worked out again.")

(defun nearest-exact (rationals degree controls dimension point)
  (let ((key (list rationals degree controls dimension point)))
    (multiple-value-bind (kept found) (gethash key *nearest-exact*)
      (unless found
        (setf kept (multiple-value-list (exact-least-points rationals degree controls dimension point (expt 2 -70)))
              (gethash key *nearest-exact*) kept))
      (values (first kept) (second kept)))))

(defun nearest-exact-at (rationals degree dimension controls point parameter)
  "At a parameter of the curve, exactly: the squared distance from the point, the residual, and the squared speed."
  (let* ((n (- (length rationals) degree 1))
         (span (if (= parameter (aref rationals n))
                   (loop :for s :from (1- n) :downto degree :when (< (aref rationals s) (aref rationals (1+ s))) :return s)
                   (loop :for s :from degree :below n
                         :when (and (<= (aref rationals s) parameter) (< parameter (aref rationals (1+ s)))) :return s)))
         (squared 0) (residual 0) (speed 0))
    (dotimes (c dimension)
      (destructuring-bind (value slope)
          (exact-curve-column rationals degree span parameter
                              (loop :for j :from (- span degree) :to span :collect (aref controls (+ (* j dimension) c)))
                              1)
        (let ((gap (- value (aref point c))))
          (incf squared (* gap gap))
          (incf residual (* gap slope))
          (incf speed (* slope slope)))))
    (values squared residual speed)))

(defun nearest-check-point (label knots degree dimension controls point step tie foot report measures record
                            &key (expect-resolved t))
  "One point's answer against the exact reference, by the promises of the contract."
  (let* ((rationals (map 'vector #'rational knots)) (exact-controls (map 'vector #'rational controls))
         (exact-point (map 'vector #'rational point))
         (start (aref rationals degree)) (end (aref rationals (- (length rationals) degree 1)))
         (scale (max 1 (reduce #'max exact-controls :key #'abs) (reduce #'max exact-point :key #'abs))))
    (multiple-value-bind (least flat)
        (nearest-exact rationals degree exact-controls dimension exact-point)
      (incf (nearest-record-points record))
      (cond
        ((= report nearest:report-unresolved)
         (incf (nearest-record-unresolved record))
         (assert (and (/= foot foot) (every (lambda (x) (/= x x)) measures)) ()
                 "~A: unresolved, and a parameter or a measure was returned: ~S ~S." label foot measures)
         (when expect-resolved
           (assert flat () "~A: unresolved, and the curve has least points ~S." label
                   (mapcar (lambda (entry) (list (float (first entry) 1d0) (sqrt (float (second entry) 1d0)) (third entry)))
                           least))))
        (t
         (assert (and (basis-finite-p foot) (every #'basis-finite-p measures)) ()
                 "~A: an answer that is not finite: ~S ~S." label foot measures)
         (assert (<= start (rational foot) end) () "~A: the parameter ~S is outside the domain." label foot)
         (assert least () "~A: an answer, and the reference finds no least point." label)
         (destructuring-bind (distance residual residual-bound speed) (coerce measures 'list)
           (let* ((t0 (rational foot))
                  (nearest-first (sort (copy-list least) #'< :key #'second))
                  (best (first nearest-first))
                  ;; The least point the answer belongs to: the one nearest to it in parameter.
                  (mine (first (sort (copy-list least) #'< :key (lambda (entry) (abs (- (first entry) t0))))))
                  (others (remove mine least)))
             (multiple-value-bind (squared exact-residual squared-speed)
                 (nearest-exact-at rationals degree dimension exact-controls exact-point t0)
               ;; The measures are of the returned parameter: the residual to its bound, the distance
               ;; and the speed to a part in a thousand million of the size of the problem.
               (assert (<= (abs (- (rational residual) exact-residual)) (rational residual-bound)) ()
                       "~A: the residual ~S is off by ~E, and its bound is ~E." label residual
                       (float (abs (- (rational residual) exact-residual)) 1d0) residual-bound)
               (assert (<= (abs (- (* (rational distance) (rational distance)) squared))
                           (* (expt 10 -9) (+ squared (* scale scale))))
                       () "~A: the distance ~S, and exactly ~E." label distance (sqrt (float squared 1d0)))
               (assert (<= (abs (- (* (rational speed) (rational speed)) squared-speed))
                           (* (expt 10 -9) (+ squared-speed 1)))
                       () "~A: the speed ~S, and exactly ~E." label speed (sqrt (float squared-speed 1d0)))
               ;; The report is decided by the parameter and by nothing else.
               (unless (= report nearest:report-tied)
                 (assert (= report (cond ((= t0 start) nearest:report-start) ((= t0 end) nearest:report-end)
                                         (t nearest:report-foot)))
                         () "~A: the report ~D does not go with the parameter ~S." label report foot))
               ;; Promise 1: the parameter is within the step of a least point, or its residual is
               ;; zero to within its bound. An end that the distance falls toward is neither, and
               ;; is where it is exactly.
               (cond
                 ((and (member (third mine) '(:start :end)) (= t0 (first mine))))
                 ((<= (abs (- t0 (first mine))) (+ (rational step) (* (expt 2 -60) (- end start))))
                  (incf (nearest-record-by-bracket record)))
                 (t
                  (assert (<= (abs exact-residual) (* 2 (rational residual-bound))) ()
                          "~A: the parameter ~S is ~E from the least point at ~E, and its residual ~E is beyond twice its bound ~E."
                          label foot (float (abs (- t0 (first mine))) 1d0) (float (first mine) 1d0)
                          (float exact-residual 1d0) residual-bound)
                  (incf (nearest-record-by-residual record))))
               (cond
                 ((= report nearest:report-tied)
                  (incf (nearest-record-tied record))
                  ;; A tie is reported only where there is one, to within a part in a million.
                  (assert (and others
                               (<= (sqrt (float (second (second nearest-first)) 1d0))
                                   (+ (* (sqrt (float (second best) 1d0)) (+ 1 1d-6)) tie (* 1d-6 (float scale 1d0)))))
                          () "~A: tied, and the least points are ~S." label
                          (mapcar (lambda (entry) (list (float (first entry) 1d0) (sqrt (float (second entry) 1d0))))
                                  nearest-first)))
                 (t
                  (if (= report nearest:report-foot) (incf (nearest-record-feet record)) (incf (nearest-record-ends record)))
                  ;; Promise 2: the answer is the nearest, and every other least point is farther
                  ;; than the returned distance by more than the tie.
                  (assert (eq mine best) () "~A: the answer is at ~S, and the nearest least point is at ~E." label foot
                          (float (first best) 1d0))
                  (dolist (other others)
                    (assert (> (second other) (expt (+ (rational distance) (rational tie)) 2)) ()
                            "~A: another least point at ~E is at ~E, within the tie ~S of the answer's ~S, and no tie was reported."
                            label (float (first other) 1d0) (sqrt (float (second other) 1d0)) tie distance))))))))))))

(defun nearest-run (search knots degree dimension controls points step tie record
                    &key hints (expect-resolved t) label)
  "One call for a batch of points, each answer checked. Returns the feet and the reports."
  (let* ((count (/ (length points) dimension))
         (feet (basis-sentinel count)) (measures (basis-sentinel (* 4 count)))
         (reports (make-array count :element-type '(unsigned-byte 62) :initial-element 99))
         (code (nc:nearest-code search controls points (or hints (doubles)) step tie feet reports measures)))
    (assert (= 0 code) () "~A: the search was refused with ~D." label code)
    (dotimes (i count)
      (nearest-check-point (format nil "~A, point ~D ~S" label i (subseq points (* i dimension) (* (1+ i) dimension)))
                           knots degree dimension controls (subseq points (* i dimension) (* (1+ i) dimension)) step tie
                           (aref feet i) (aref reports i) (subseq measures (* 4 i) (* 4 (1+ i))) record
                           :expect-resolved expect-resolved))
    (values feet reports measures)))

(defun nearest-points (count dimension size)
  "Points from the fixed sequence, in a box of this half-size about the origin."
  (let ((found (make-array (* count dimension) :element-type 'double-float)))
    (dotimes (i (length found) found)
      (setf (aref found i) (coerce (* (- (basis-random 2001) 1000) 1/1000 size) 'double-float)))))

(defun nearest-family (record)
  "Curves of degrees 2 to 5 in one, two and three dimensions, on knots clamped and not, even and uneven, with
interior knots repeated as often as the search allows; points near them and far; with no hint, with the answer as
the hint, and with a hint that is wrong. Returns the number of curves."
  (let ((curves 0))
    (flet ((try (degree breaks multiplicities dimension offset)
             (let ((knots (basis-knots breaks multiplicities)))
               (assert (= 0 (basis-knot-rule degree knots)) () "The fixture ~S is not a knot vector of degree ~D." knots
                       degree)
               (let* ((handle (basis:make-basis degree knots 2)) (search (nearest:make-search handle dimension 60 4000))
                      (n (basis:control-count handle))
                      (controls (let ((found (make-array (* n dimension) :element-type 'double-float)))
                                  (dotimes (i (length found) found)
                                    (setf (aref found i)
                                          (coerce (+ offset (* (- (basis-random 2001) 1000) 1/97)) 'double-float)))))
                      (points (let ((found (nearest-points 4 dimension 14)))
                                (dotimes (i (length found) found) (incf (aref found i) offset))))
                      (label (format nil "degree ~D, dimension ~D, knots ~S, controls ~S" degree dimension knots controls))
                      (step (* 1d-13 (- (basis:domain-end handle) (basis:domain-start handle)))))
                 (incf curves)
                 (multiple-value-bind (feet reports) (nearest-run search knots degree dimension controls points step 0d0 record
                                                                  :label label)
                   ;; The answers as hints, and hints that are wrong or outside the domain: the promises
                   ;; hold as before, and an answer that was resolved is the same answer.
                   (let ((right (map '(simple-array double-float (*))
                                     (lambda (foot) (if (= foot foot) foot (basis:domain-start handle))) feet))
                         (wrong (map '(simple-array double-float (*))
                                     (lambda (foot) (declare (ignore foot))
                                       (+ (basis:domain-start handle)
                                          (* (basis-random 1300) 1d-3 (- (basis:domain-end handle) (basis:domain-start handle)))))
                                     feet)))
                     (dolist (hints (list right wrong))
                       (multiple-value-bind (hinted hinted-reports)
                           (nearest-run search knots degree dimension controls points step 0d0 record :hints hints
                                                                                                         :label label)
                         (dotimes (i (length feet))
                           (when (and (< (aref reports i) 3) (< (aref hinted-reports i) 3))
                             (assert (and (= (aref reports i) (aref hinted-reports i))
                                          (<= (abs (- (aref feet i) (aref hinted i))) (* 4 step)))
                                     () "~A, point ~D: ~S with no hint and ~S with one." label i (aref feet i)
                                     (aref hinted i))))))))))))
      (loop :for degree :from 2 :to 5
            :do (try degree '(0 1) (list (1+ degree) (1+ degree)) 2 0)
                (try degree '(0 1/4 1/2 3/4 1) (list (1+ degree) 1 1 1 (1+ degree)) 2 0)
                (try degree '(0 1/3 1) (list (1+ degree) (1- degree) (1+ degree)) 3 0)
                (try degree (loop :for i :from 0 :to (+ 3 (* 2 degree)) :collect (- (* i 3/7) 2))
                     (make-list (+ 4 (* 2 degree)) :initial-element 1) 2 0)
                (try degree '(-3 -1 0 2 5) (list (1+ degree) 1 (max 1 (- degree 2)) 1 (1+ degree)) 1 0)
                (try degree '(0 1/1024 1 17 18) (list (1+ degree) 1 1 1 (1+ degree)) 2 0)
                ;; Far from the origin, where the point of a curve is small beside its control points.
                (try degree '(0 1/2 1) (list (1+ degree) 1 (1+ degree)) 2 1000000)))
    curves))

;;; ---- Answers that are known in advance -------------------------------------------------------

(defun nearest-known-tests (record)
  ;; The cubic that goes up from (0, 0), across, and down to (2, 0): symmetric about x = 1.
  (let* ((knots (doubles 0d0 0d0 0d0 0d0 1d0 1d0 1d0 1d0)) (controls (doubles 0d0 0d0 0d0 3d0 2d0 3d0 2d0 0d0))
         (handle (basis:make-basis 3 knots 2)) (search (nearest:make-search handle 2 60 4000)))
    (flet ((reports-of (points tie &optional (step 1d-12))
             (multiple-value-bind (feet reports) (nearest-run search knots 3 2 controls points step tie record
                                                              :label "the cubic that bends back")
               (values (coerce reports 'list) feet))))
      ;; Above the top: one foot, at the middle. Below the middle of the chord: two feet as near as
      ;; each other, one on each side, which is a tie whatever the tolerance.
      (multiple-value-bind (reports feet) (reports-of (doubles 1d0 4d0) 0d0)
        (assert (and (equal reports (list nearest:report-foot)) (<= (abs (- (aref feet 0) 0.5d0)) 1d-9))))
      (assert (equal (list nearest:report-tied) (reports-of (doubles 1d0 0.5d0) 0d0)))
      ;; Moved off the axis by a thousandth the tie is broken, and is reported again when the
      ;; tolerance is wider than the difference it makes.
      (assert (equal (list nearest:report-foot) (reports-of (doubles 1.001d0 0.5d0) 0d0)))
      (assert (equal (list nearest:report-tied) (reports-of (doubles 1.001d0 0.5d0) 1d-2)))
      ;; A second least point much farther, on the far side and so looked at after the nearer one
      ;; is known, and a tie wide enough to take it in: the part of the curve that holds it must
      ;; not be set aside for being farther than the nearest alone.
      (assert (equal (list nearest:report-tied) (reports-of (doubles 0.2d0 0.5d0) 1.7d0)))
      (assert (equal (list nearest:report-foot) (reports-of (doubles 0.2d0 0.5d0) 1d0)))
      ;; With a tie wider still, the place between the two where the distance is greatest is
      ;; itself within the tie of the least. The search cannot tell a greatest value from a least
      ;; one that it has not found, and says that it could not show an answer.
      (multiple-value-bind (feet reports)
          (nearest-run search knots 3 2 controls (doubles 0.2d0 0.5d0) 1d-12 2.5d0 record :expect-resolved nil
                                                                                          :label "a greatest distance within the tie")
        (declare (ignore feet))
        (assert (= nearest:report-unresolved (aref reports 0))))
      ;; One foot, a little before the middle of the span, and a tie of a hundredth. The interval
      ;; that begins at the middle is convex and rises from its left end, which is nearly as near
      ;; as the foot and is no least point: it must not be offered as a second answer.
      (assert (equal (list nearest:report-foot) (reports-of (doubles 0.97d0 4d0) 1d-2)))
      (assert (equal (list nearest:report-foot) (reports-of (doubles 0.999d0 4d0) 1d-2)))
      ;; Beyond each end, the end exactly; and a batch of all of them at once, in any order.
      (multiple-value-bind (reports feet) (reports-of (doubles 0d0 -1d0 2d0 -1d0 1d0 4d0 -0.5d0 -0.25d0) 0d0)
        (assert (equal reports (list nearest:report-start nearest:report-end nearest:report-foot nearest:report-start)))
        (assert (and (= 0d0 (aref feet 0)) (= 1d0 (aref feet 1)) (= 0d0 (aref feet 3)))))
      ;; A point of the curve itself: the distance is zero and the residual with it.
      (assert (equal (list nearest:report-foot) (reports-of (doubles 1d0 2.25d0) 0d0)))
      ;; With a step of zero the bracket closes as far as the arithmetic allows.
      (assert (equal (list nearest:report-foot) (reports-of (doubles 0.3d0 3.5d0) 0d0 0d0)))))
  ;; A curve confined to a line, which goes down past the point and comes back up past it: two
  ;; least points, both at distance zero, and so a tie whatever the tolerance. The parameter
  ;; returned for each is only within the step of its crossing, and the curve is fast there, so
  ;; the two distances computed are far from equal: it is the distance at the least point that
  ;; a tie is judged by. This is the case that showed the first rule for a tie to be wrong.
  (let* ((knots (doubles -3d0 -3d0 -3d0 -1d0 0d0 2d0 5d0 5d0 5d0)) (controls (doubles -2d0 3.5d0 -10d0 3.75d0 1.25d0 9.75d0))
         (handle (basis:make-basis 2 knots 2)) (search (nearest:make-search handle 1 60 4000)))
    (multiple-value-bind (feet reports) (nearest-run search knots 2 1 controls (doubles -4.125d0) 1d-12 0d0 record
                                                     :label "a line crossed twice")
      (declare (ignore feet))
      (assert (= nearest:report-tied (aref reports 0)) () "A point crossed twice was reported as ~D." (aref reports 0))))
  ;; A foot that is an interior knot: the curve y = x on the knots 0, 1/2, 1 seen from above the knot.
  ;; A straight line is convex as it stands, so no halving is allowed and none is needed; and the
  ;; candidates of the two spans that meet at the knot are one least point, not a tie.
  (let* ((knots (doubles 0d0 0d0 0d0 0.5d0 1d0 1d0 1d0)) (controls (doubles 0d0 0d0 0.25d0 0.25d0 0.75d0 0.75d0 1d0 1d0))
         (handle (basis:make-basis 2 knots 2)) (search (nearest:make-search handle 2 0 100)))
    (multiple-value-bind (feet reports) (nearest-run search knots 2 2 controls (doubles 0d0 1d0) 1d-12 0d0 record
                                                     :label "a foot on a knot")
      (assert (and (= nearest:report-foot (aref reports 0)) (<= (abs (- (aref feet 0) 0.5d0)) 1d-12)))))
  ;; A curve that is a single point: every parameter is as near as every other, and none is returned.
  ;; Nothing is ever set aside, so the intervals double at every halving: it is the budget that ends
  ;; the search, long before the depth would.
  (let* ((knots (doubles 0d0 0d0 0d0 1d0 1d0 1d0)) (controls (doubles 1d0 1d0 1d0 1d0 1d0 1d0))
         (handle (basis:make-basis 2 knots 2)) (search (nearest:make-search handle 2 60 500)))
    (multiple-value-bind (feet reports) (nearest-run search knots 2 2 controls (doubles 0d0 0d0 1d0 1d0) 1d-12 0d0 record
                                                     :label "a curve that is a point")
      (declare (ignore feet))
      (assert (every (lambda (report) (= report nearest:report-unresolved)) reports))))
  ;; No work allowed: a point whose answer needs a span halved is left unresolved.
  (let* ((knots (doubles 0d0 0d0 0d0 0d0 1d0 1d0 1d0 1d0)) (controls (doubles 0d0 0d0 0d0 3d0 2d0 3d0 2d0 0d0))
         (handle (basis:make-basis 3 knots 2)) (search (nearest:make-search handle 2 0 100)))
    (multiple-value-bind (feet reports) (nearest-run search knots 3 2 controls (doubles 1d0 0.5d0 1d0 2.3d0) 1d-12 0d0 record
                                                     :expect-resolved nil :label "no halving allowed")
      (declare (ignore feet))
      (assert (every (lambda (report) (= report nearest:report-unresolved)) reports) ()
              "With no halving a bent curve was resolved: ~S." reports)))
  (format t "SPLINE-NEAREST-KNOWN-PASS~%"))

;;; ---- Refusals -------------------------------------------------------------------------------

(defun nearest-refusal-tests ()
  ;; A basis the search cannot be made for.
  (flet ((made (degree knots order dimension)
           (nc:make-code (basis:make-basis degree knots order) dimension 8 100)))
    (assert (= 1 (made 1 (doubles 0d0 0d0 1d0 1d0) 2 2)))
    (assert (= 2 (made 3 (doubles 0d0 0d0 0d0 0d0 1d0 1d0 1d0 1d0) 1 2)))
    (assert (= 4 (made 3 (doubles 0d0 0d0 0d0 0d0 1d0 1d0 1d0 1d0) 2 0)))
    (assert (= 4 (made 3 (doubles 0d0 0d0 0d0 0d0 1d0 1d0 1d0 1d0) 2 257)))
    (assert (= 0 (made 3 (doubles 0d0 0d0 0d0 0d0 1d0 1d0 1d0 1d0) 2 256)))
    ;; An interior knot as often as the degree is a corner; one fewer is not.
    (assert (= 3 (made 3 (doubles 0d0 0d0 0d0 0d0 1d0 1d0 1d0 2d0 2d0 2d0 2d0) 2 2)))
    (assert (= 0 (made 3 (doubles 0d0 0d0 0d0 0d0 1d0 1d0 2d0 2d0 2d0 2d0) 2 2)))
    (assert (= 3 (made 2 (doubles 0d0 0d0 0d0 1d0 1d0 2d0 2d0 2d0) 2 2)))
    ;; Unclamped: the knots at the ends of the domain may be repeated like any other outside it.
    (assert (= 0 (made 2 (doubles 0d0 1d0 2d0 3d0 4d0 5d0) 2 2))))
  (let* ((knots (doubles 0d0 0d0 0d0 0d0 1d0 1d0 1d0 1d0)) (controls (doubles 0d0 0d0 0d0 3d0 2d0 3d0 2d0 0d0))
         (handle (basis:make-basis 3 knots 2)) (search (nearest:make-search handle 2 30 1000))
         (points (doubles 1d0 4d0 0d0 -1d0)) (nan (- sb-ext:double-float-positive-infinity sb-ext:double-float-positive-infinity))
         (infinity sb-ext:double-float-positive-infinity))
    (flet ((refused (code controls points hints step tie feet-length reports-length measures-length what)
             (let ((feet (basis-sentinel feet-length)) (measures (basis-sentinel measures-length))
                   (reports (make-array reports-length :element-type '(unsigned-byte 62) :initial-element 99)))
               (assert (= code (nc:nearest-code search controls points hints step tie feet reports measures)) ()
                       "~A: status ~D, not ~D." what (nc:nearest-code search controls points hints step tie feet reports measures)
                       code)
               (assert (and (basis-untouched-p feet) (basis-untouched-p measures) (every (lambda (r) (= r 99)) reports))
                       () "~A: refused after writing." what))))
      (refused 1 (doubles 0d0 0d0 0d0 3d0 2d0 3d0) points (doubles) 1d-12 0d0 2 2 8 "a control point too few")
      (refused 1 controls (doubles 1d0 4d0 0d0) (doubles) 1d-12 0d0 1 1 4 "a point with a coordinate missing")
      (refused 1 controls points (doubles 0.5d0) 1d-12 0d0 2 2 8 "one hint for two points")
      (refused 1 controls points (doubles) 1d-12 0d0 1 2 8 "a parameter too few")
      (refused 1 controls points (doubles) 1d-12 0d0 2 3 8 "a report too many")
      (refused 1 controls points (doubles) 1d-12 0d0 2 2 6 "measures for three numbers a point")
      (refused 2 controls points (doubles) -1d-12 0d0 2 2 8 "a step below zero")
      (refused 2 controls points (doubles) nan 0d0 2 2 8 "a step that is not a number")
      (refused 2 controls points (doubles) infinity 0d0 2 2 8 "a step without bound")
      (refused 2 controls points (doubles) 1d-12 -1d0 2 2 8 "a tie below zero")
      (refused 2 controls points (doubles) 1d-12 nan 2 2 8 "a tie that is not a number")
      (refused 3 (doubles 0d0 0d0 0d0 3d0 2d0 3d0 2d0 nan) points (doubles) 1d-12 0d0 2 2 8 "a control point that is not a number")
      (refused 3 (doubles infinity 0d0 0d0 3d0 2d0 3d0 2d0 0d0) points (doubles) 1d-12 0d0 2 2 8 "a control point without bound")
      (refused 3 controls (doubles 1d0 4d0 nan -1d0) (doubles) 1d-12 0d0 2 2 8 "a point that is not a number")
      (refused 3 controls points (doubles 0.5d0 nan) 1d-12 0d0 2 2 8 "a hint that is not a number")
      ;; The sizes are asked before the tolerances, and those before the numbers.
      (refused 1 controls (doubles 1d0 4d0 nan) (doubles) -1d0 0d0 1 1 4 "three things wrong at once")
      (refused 2 controls (doubles 1d0 4d0 nan -1d0) (doubles) -1d0 0d0 2 2 8 "two things wrong at once"))
    ;; A hint outside the domain is no error: it is a guess that costs nothing.
    (let ((feet (basis-sentinel 2)) (reports (indices 99 99)) (measures (basis-sentinel 8)))
      (assert (= 0 (nc:nearest-code search controls points (doubles -7d0 55d0) 1d-12 0d0 feet reports measures)))
      (assert (equalp reports (indices nearest:report-foot nearest:report-start))))
    ;; No point is a batch like any other.
    (assert (= 0 (nc:nearest-code search controls (doubles) (doubles) 1d-12 0d0 (doubles) (indices) (doubles))))
    ;; An output that is an input, or the other output.
    (let ((view (basis:knots handle)))
      (flet ((aliased (controls points hints feet measures what)
               (let ((before (mapcar #'copy-seq (list controls points hints feet measures))))
                 (assert (= 108 (nc:nearest-code search controls points hints 1d-12 0d0 feet (indices 99 99) measures)) ()
                         "~A: not the typed error." what)
                 (assert (every #'same-bits-p (list controls points hints feet measures) before) ()
                         "~A: refused after writing." what))))
        (let ((eight (basis-sentinel 8)) (two (doubles 0.25d0 0.75d0)) (four (doubles 1d0 4d0 0d0 -1d0)))
          (aliased controls points (doubles) eight eight "the parameters and the measures one array")
          (aliased eight points (doubles) (basis-sentinel 2) eight "the measures and the control points one array")
          (aliased controls points two two (basis-sentinel 8) "the parameters and the hints one array")
          (aliased controls four (doubles) four (basis-sentinel 8) "the parameters and the points one array")
          (aliased controls four (doubles) (basis-sentinel 2) four "the measures and the points one array")
          (aliased controls points two (basis-sentinel 2) two "the measures and the hints one array")
          (aliased controls points (doubles) view (basis-sentinel 8) "the parameters the basis's own knots")
          (aliased controls points (doubles) (basis-sentinel 2) view "the measures the basis's own knots"))
        (assert (same-bits-p knots view) () "A refused search wrote the basis's knots."))))
  (format t "SPLINE-NEAREST-REFUSALS-PASS~%"))

;;; ---- A batch is its points, and allocation ---------------------------------------------------

(defun nearest-batch-tests ()
  (let* ((knots (doubles 0d0 0d0 0d0 0d0 0.3d0 0.6d0 1d0 1d0 1d0 1d0))
         (controls (doubles 0d0 0d0 1d0 2d0 2d0 -1d0 3d0 3d0 4d0 0d0 5d0 1d0))
         (handle (basis:make-basis 3 knots 2)) (search (nearest:make-search handle 2 40 2000))
         (points (doubles 2d0 2d0 -1d0 0d0 6d0 1d0 2.5d0 0.5d0 4d0 4d0 0d0 5d0)) (count 6)
         (feet (basis-sentinel count)) (measures (basis-sentinel (* 4 count)))
         (reports (make-array count :element-type '(unsigned-byte 62) :initial-element 99)))
    (assert (= 0 (nc:nearest-code search controls points (doubles) 1d-13 0d0 feet reports measures)))
    (dotimes (i count)
      (let ((foot (basis-sentinel 1)) (measure (basis-sentinel 4)) (report (indices 99)))
        (assert (= 0 (nc:nearest-code search controls (subseq points (* 2 i) (* 2 (1+ i))) (doubles) 1d-13 0d0 foot report
                                      measure)))
        (assert (and (same-bits-p foot (subseq feet i (1+ i))) (= (aref report 0) (aref reports i))
                     (same-bits-p measure (subseq measures (* 4 i) (* 4 (1+ i)))))
                () "Point ~D of the batch differs from its own call." i)))
    ;; Allocation, through a loop compiled in another file: nothing in a warmed call.
    (let* ((tally (indices 0))
           (bytes (bytes-a-call (lambda (rounds) (nc:nearest-loop search controls points (doubles) 1d-13 0d0 feet reports
                                                                  measures tally rounds))
                                2000))
           (hints (copy-seq feet))
           (hinted (bytes-a-call (lambda (rounds) (nc:nearest-loop search controls points hints 1d-13 0d0 feet reports
                                                                   measures tally rounds))
                                 2000)))
      (assert (= 0 bytes) () "nearest! allocates ~D bytes a call of ~D points." bytes count)
      (assert (= 0 hinted) () "nearest! with hints allocates ~D bytes a call." hinted)
      (assert (= 0 (aref tally 0)))
      (format t "SPLINE-NEAREST-BATCH-PASS allocation: ~D bytes a call of ~D points, ~D with hints~%" bytes count hinted))))

;;; ---- The run --------------------------------------------------------------------------------

(defun run-spline-nearest-tests ()
  (clrhash *nearest-exact*)
  (nearest-refusal-tests)
  (let ((record (make-nearest-record)))
    (nearest-known-tests record)
    (let ((curves (nearest-family record)))
      (assert (and (plusp (nearest-record-feet record)) (plusp (nearest-record-ends record))
                   (plusp (nearest-record-tied record)) (plusp (nearest-record-unresolved record))
                   (plusp (nearest-record-by-bracket record)))
              () "A kind of answer was never reached: ~S." record)
      (format t "SPLINE-NEAREST-PASS curves=~D points=~D feet=~D ends=~D tied=~D unresolved=~D~%" curves
              (nearest-record-points record) (nearest-record-feet record) (nearest-record-ends record)
              (nearest-record-tied record) (nearest-record-unresolved record))
      (format t "SPLINE-NEAREST-CERTIFIED within the step of the exact least point: ~D; by a residual within its bound alone: ~D~%"
              (nearest-record-by-bracket record) (nearest-record-by-residual record))))
  (nearest-batch-tests))
