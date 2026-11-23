(in-package #:coalton-geometry/tests)

;;; The scale-sweep roster. One question is asked of every exported call that takes or returns
;;; floating-point numbers, or returns a status: what does it do with the same problem at
;;; another scale? Multiplying every input of a problem by a power of two changes no
;;; significand, so each output has one right value at each scale: the output at scale 1
;;; times a known power of the factor. A call is run across the whole range of the format and
;;; each run is put in one class:
;;;
;;;   :exact    every output is that value, bit for bit;
;;;   :close    every output is within the entry's tolerance of it, measured against the largest
;;;             magnitude in its array;
;;;   :looser   an upper bound came out above its scaled value, which a bound may;
;;;   :lost     the call succeeded and an output's right value is too small to be a normal
;;;             number: what came back is zero or has lost digits;
;;;   :refused  the call refused, and some output's right value cannot be held at this scale;
;;;   :limit    the call refused although every output's right value can be held: the scale is
;;;             outside what the routine's own arithmetic reaches;
;;;   :no-input an input of the problem is not a normal number at this scale;
;;;   :wrong    the call succeeded and an output is neither its right value nor lost.
;;;
;;; :wrong fails wherever it appears. The other classes are declared for each entry as the
;;; ranges of the sweep they hold over, and the roster fails when a run leaves its declared
;;; class in either direction: a range that shrinks is a regression, and one that grows is
;;; an improvement the entry has to be changed to record.
;;;
;;; The members are read from the sources, as the aliasing roster's are, and each entry names
;;; the calls it answers for. A name is accepted only if the entry's own code calls it.

(defparameter *sweep-exponents*
  '(-1020 -1000 -800 -600 -520 -512 -510 -400 -300 -200 -100 -50 0 50 100 200 300 400 510 512 520 600 800 1000 1020)
  "The powers of two a problem is multiplied by. All even, so that a square root of the factor is a power of two.")

(define-condition sweep-premise (error)
  ((text :initarg :text :reader sweep-premise-text))
  (:report (lambda (condition stream) (write-string (sweep-premise-text condition) stream))))

(defun sweep-finite-p (value)
  (or (not (floatp value)) (and (= value value) (not (sb-ext:float-infinity-p value)))))

(defun sweep-number (value k)
  "VALUE times 2^K. An input the format cannot hold as a normal number is no input: SWEEP-PREMISE is signalled."
  (let ((scaled (scale-float (coerce value 'double-float) k)))
    (unless (and (sweep-finite-p scaled)
                 (or (zerop value) (>= (abs scaled) least-positive-normalized-double-float)))
      (error 'sweep-premise :text (format nil "~S times 2^~D is not a normal number." value k)))
    scaled))

(defun sweep-array (array k)
  (map '(simple-array double-float (*)) (lambda (value) (sweep-number value k)) array))

(defmacro sweep-need (form constructor)
  "Run FORM, a call that returns a status, and refuse the run unless the status is CONSTRUCTOR."
  (let ((status (gensym "STATUS")))
    `(let ((,status ,form))
       (unless (eq ,status (coalton:coalton ,constructor))
         (error "~(~A~) returned ~A" ',(first form) ,status)))))

(defun sweep-out (label value power &key (kind :law) bound)
  "One output of a run: its right value at scale 2^k is its value at scale 1 times 2^(POWER k). KIND :law for a
value, :bound for an upper bound, which may come out larger, and :within for a quantity with no value of its own
that must lie in [0, BOUND 2^(POWER k)]."
  (list label (if (arrayp value) (copy-seq value) value) power kind bound))

;;; ---- The class of one run ------------------------------------------------------------------

(defparameter *sweep-order* '(:exact :close :looser :lost :wrong))

(defun sweep-in-range-p (expected)
  (or (zerop expected)
      (<= (rational least-positive-normalized-double-float) (abs expected) (rational most-positive-double-float))))

(defun sweep-element (actual reference largest shift kind bound tolerance)
  "The class of one number against its value at scale 1. LARGEST is the largest magnitude at scale 1 in its array."
  (cond
    ((eq kind :within)
     (if (and (sweep-finite-p actual) (<= 0 (rational actual) (* (rational bound) (expt 2 shift)))) :exact :wrong))
    ((not (sweep-finite-p actual)) (if (and (eq kind :bound) (= actual actual)) :looser :wrong))
    (t
     (let ((expected (* (rational reference) (expt 2 shift))) (value (rational actual)))
       (cond ((= value expected) :exact)
             ;; A bound whose scaled value the format cannot hold is still a bound if it is above it.
             ((and (eq kind :bound) (not (sweep-in-range-p expected))) (if (> value expected) :looser :wrong))
             ((not (sweep-in-range-p expected)) :lost)
             ((<= (abs (- value expected)) (* tolerance largest (expt 2 shift))) :close)
             ((and (eq kind :bound) (> value expected)) :looser)
             (t :wrong))))))

(defun sweep-values (value)
  (if (arrayp value) (coerce value 'list) (list value)))

(defun sweep-holdable-p (reference k)
  "Whether every value of the outputs at scale 1 has a scaled value the format can hold at 2^K."
  (loop :for (nil value power kind) :in reference
        :always (or (not (eq kind :law))
                    (loop :for r :in (sweep-values value)
                          :always (and (sweep-finite-p r) (sweep-in-range-p (* (rational r) (expt 2 (* power k)))))))))

(defun sweep-class (run reference k tolerance)
  "The class of the run at scale 2^K against the outputs at scale 1, and for a run that is not :exact what decided
it: the output and the number, or the refusal's own words."
  (let ((outputs (handler-case (funcall run k)
                   (sweep-premise (condition)
                     (return-from sweep-class (values :no-input (princ-to-string condition))))
                   (error (condition)
                     (return-from sweep-class
                       (values (if (sweep-holdable-p reference k) :limit :refused)
                               (substitute #\Space #\Newline (princ-to-string condition)))))))
        (class :exact) (decided nil))
    (assert (= (length outputs) (length reference)) ()
            "At 2^~D the run has ~D outputs and at scale 1 it has ~D." k (length outputs) (length reference))
    (loop :for (label value power kind bound) :in outputs
          :for (nil reference-value) :in reference
          :do (let* ((shift (* power k)) (actual (sweep-values value)) (expected (sweep-values reference-value))
                     (largest (loop :for r :in expected :maximize (if (sweep-finite-p r) (abs (rational r)) 0))))
                (assert (integerp shift) () "~A: 2^(~S * ~D) is not a power of two." label power k)
                (flet ((take (found detail)
                         (when (> (position found *sweep-order*) (position class *sweep-order*))
                           (setf class found decided detail))))
                  (if (/= (length actual) (length expected))
                      (take :wrong (list label :length (length actual) :at-scale-1 (length expected)))
                      (loop :for a :in actual :for r :in expected :for position :from 0
                            :do (take (sweep-element a r largest shift kind bound tolerance)
                                      (list label position a :at-scale-1 r)))))))
    (values class decided)))

(defun sweep-segments (classes)
  "A list of (k class), in order, as the ranges each class holds over: (first-k last-k class)."
  (let ((segments '()))
    (loop :for (k class) :in classes
          :do (if (and segments (eq (third (first segments)) class))
                  (setf (second (first segments)) k)
                  (push (list k k class) segments)))
    (nreverse segments)))

;;; ---- The members ---------------------------------------------------------------------------

(defmacro sweep-entry (name covers tolerance declared run)
  "An entry: its name, the calls it answers for, the tolerance of :close, the declared ranges, and the run, a
function of the exponent that returns the outputs. The run's source is kept, to check the calls against."
  `(list ,name ',covers ,tolerance ',declared ,run ',run))

(defun sweep-roster ()
  "The entries. No call of the library takes or returns a floating-point number yet, so there is none."
  (list))

;;; ---- The roster against the sources, and its run -------------------------------------------

(defun sweep-member-p (type-text)
  "A member of the family: a function whose type mentions a floating-point number, or whose result is a status."
  (and (search "->" type-text)
       (or (search "F64" type-text)
           (let ((end (search "Status)" type-text :from-end t))) (and end (= end (- (length type-text) 7)))))))

(defun sweep-key (symbol)
  (format nil "~(~A~):~(~A~)" (package-name (symbol-package symbol)) (symbol-name symbol)))

(defun sweep-mentions-p (form symbol)
  (cond ((eq form symbol) t)
        ((consp form) (or (sweep-mentions-p (car form) symbol) (sweep-mentions-p (cdr form) symbol)))
        (t nil)))

(defun sweep-check-entry (entry)
  "Run one entry across the sweep. Returns its ranges; prints them for an entry still to be declared."
  (destructuring-bind (name covers tolerance declared run source) entry
    (dolist (symbol covers)
      (assert (sweep-mentions-p source symbol) () "~A answers for ~S and does not call it." name symbol))
    (let* ((reference (funcall run 0)) (decisions '())
           (classes (loop :for k :in *sweep-exponents*
                          :collect (multiple-value-bind (class decided) (sweep-class run reference k tolerance)
                                     (unless (eq class :exact) (push (list k class decided) decisions))
                                     (list k class))))
           (segments (sweep-segments classes)))
      (assert (eq :exact (second (assoc 0 classes))) () "~A: two runs at scale 1 differ." name)
      (cond
        ((eq declared :measure)
         (format t "SWEEP-MEASURED ~S~%    ~S~%" name segments)
         (dolist (decision (reverse decisions)) (format t "      ~S~%" decision)))
        (t
         (assert (not (find :wrong classes :key #'second)) ()
                 "~A: a run succeeds with an output that is not its scaled value: ~S." name
                 (find :wrong decisions :key #'second))
         (assert (equal segments declared) ()
                 "~A: across the sweep the runs are~%    ~S~%and the roster declares~%    ~S" name segments declared)))
      segments)))

(defun run-scale-sweep-tests ()
  (let* ((roster (sweep-roster))
         (inventory (source-inventory #'sweep-member-p))
         (answered (remove-duplicates (loop :for entry :in roster :append (mapcar #'sweep-key (second entry)))
                                      :test #'string=))
         (measured 0) (runs 0))
    (multiple-value-bind (unanswered unknown) (alias-missing inventory answered)
      (assert (null unanswered) () "Calls with floating-point arguments or results that no entry of the sweep answers for: ~S."
              unanswered)
      (assert (null unknown) () "The sweep answers for names that are not such calls: ~S." unknown))
    (assert (equal '("coalton-geometry/new:call!") (alias-missing (cons "coalton-geometry/new:call!" inventory) answered)))
    (dolist (entry roster)
      (when (eq (fourth entry) :measure) (incf measured))
      (sweep-check-entry entry)
      (incf runs (length *sweep-exponents*)))
    ;; Control: an entry that answers for a call its run does not make is refused.
    (assert (handler-case
                (progn (sweep-check-entry
                        (sweep-entry "a control" (sweep-number sweep-array) 1d-15 ((-1020 1020 :exact))
                          (lambda (k) (list (sweep-out "a number" (sweep-number 3d0 k) 1)))))
                       nil)
              (error () t))
            () "An entry answered for a call it does not make.")
    ;; Controls for the classes: a value off its scaled value, a value the format cannot hold, a
    ;; refusal, and a bound that came out larger are each put in their class.
    (flet ((classes (run) (mapcar #'second (loop :with reference := (funcall run 0)
                                                 :for k :in '(0 100 1000)
                                                 :collect (list k (sweep-class run reference k 1d-12))))))
      (assert (equal '(:exact :exact :exact) (classes (lambda (k) (list (sweep-out "v" (sweep-number 3d0 k) 1))))))
      (assert (equal '(:exact :wrong :wrong)
                     (classes (lambda (k) (list (sweep-out "v" (if (zerop k) 3d0 (* 1.5d0 (sweep-number 3d0 k))) 1))))))
      (assert (equal '(:exact :close :close)
                     (classes (lambda (k) (list (sweep-out "v" (if (zerop k) 3d0 (* (+ 1d0 1d-14) (sweep-number 3d0 k))) 1))))))
      (assert (equal '(:exact :exact :lost) (classes (lambda (k) (list (sweep-out "v" (if (= k 1000) 0d0 (sweep-number 3d0 (* 2 k))) 2))))))
      (assert (equal '(:exact :exact :wrong)
                     (classes (lambda (k) (list (sweep-out "v" (if (= k 1000) sb-ext:double-float-positive-infinity
                                                                 (sweep-number 3d0 k))
                                                           1))))))
      (assert (equal '(:exact :limit :limit) (classes (lambda (k) (if (zerop k) (list (sweep-out "v" 3d0 1)) (error "no"))))))
      (assert (equal '(:exact :limit :refused) (classes (lambda (k) (if (zerop k) (list (sweep-out "v" 3d0 2)) (error "no"))))))
      (assert (equal '(:exact :looser :looser)
                     (classes (lambda (k) (list (sweep-out "v" (if (zerop k) 3d0 sb-ext:double-float-positive-infinity) 2
                                                           :kind :bound))))))
      (assert (equal '(:exact :close :wrong)
                     (classes (lambda (k) (list (sweep-out "v" (if (zerop k) (doubles 3d0 1d-20)
                                                                 (doubles (sweep-number 3d0 k)
                                                                          (if (= k 100) 0d0 (sweep-number 1d0 k))))
                                                           1))))))
      (assert (equal '(:exact :looser :looser)
                     (classes (lambda (k) (list (sweep-out "v" (if (zerop k) 3d0 (* 4d0 (sweep-number 3d0 k))) 1 :kind :bound))))))
      (assert (equal '(:exact :wrong :wrong)
                     (classes (lambda (k) (list (sweep-out "v" (if (zerop k) 3d0 (* 0.5d0 (sweep-number 3d0 k))) 1 :kind :bound))))))
      (assert (equal '(:exact :exact :no-input) (classes (lambda (k) (list (sweep-out "v" (sweep-number 1d10 (* 2 k)) 2)))))))
    (format t "SCALE-SWEEP-~A entries=~D calls=~D runs=~D~%" (if (zerop measured) "PASS" "MEASURED") (length roster)
            (length answered) runs)))
