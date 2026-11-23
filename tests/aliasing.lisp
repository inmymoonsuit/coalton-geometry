(in-package #:coalton-geometry/tests)

;;; The aliasing roster. One question is asked of every exported call that takes two or more
;;; arrays: what happens when two of them are one array? The answer the library gives is that
;;; such a call either does exactly what it does with two distinct arrays of equal contents,
;;; or refuses before it writes anything.
;;;
;;; The members are not listed by hand. They are read from the sources: every exported
;;; function whose declared type has two or more arrays among its own parameters. A call
;;; added to the library joins the inventory by being declared, and this file fails until it
;;; has an entry here or a stated reason for having none.

;;; ---- The inventory, from the sources ---------------------------------------------------

(defun alias-whitespace-p (character)
  (member character '(#\Space #\Newline #\Return #\Tab)))

(defun alias-balanced (text start)
  "The parenthesized form that opens at START."
  (let ((depth 0))
    (loop :for i :from start :below (length text) :do
      (case (char text i)
        ((#\() (incf depth))
        ((#\)) (decf depth) (when (zerop depth) (return-from alias-balanced (subseq text start (1+ i)))))))
    (error "Unbalanced form at ~D." start)))

(defun alias-parameters (type-text)
  "The parameters of a function type '(A * B * (C * D -> E) -> F)', split where it is one level deep. NIL for a
type that is not a function's."
  (let ((inner (subseq type-text 1 (1- (length type-text)))) (depth 0) (parts '()) (current '()))
    (flet ((finish () (push (string-trim " " (coerce (reverse current) 'string)) parts) (setf current '())))
      (loop :for i :from 0 :below (length inner) :do
        (let ((c (char inner i)))
          (case c ((#\() (incf depth)) ((#\)) (decf depth)))
          (cond
            ((and (zerop depth) (char= c #\-) (< (1+ i) (length inner)) (char= (char inner (1+ i)) #\>))
             (finish)
             (return-from alias-parameters (nreverse parts)))
            ((and (zerop depth) (char= c #\*) (plusp i) (alias-whitespace-p (char inner (1- i)))
                  (< (1+ i) (length inner)) (alias-whitespace-p (char inner (1+ i))))
             (finish))
            (t (push c current))))))
    nil))

(defun alias-exported-names (text)
  (let ((start (search "(:export" text)) (end (search "(cl:in-package" text)) (names '()))
    (when (and start end)
      (loop :with i := start
            :for at := (search "#:" text :start2 i :end2 end)
            :while at
            :do (let ((stop (position-if (lambda (c) (or (alias-whitespace-p c) (member c '(#\( #\))))) text
                                         :start (+ at 2))))
                  (push (subseq text (+ at 2) stop) names)
                  (setf i stop))))
    names))

(defun source-inventory (member-p)
  "Every exported name of the library whose declared type MEMBER-P accepts, as 'package:name' strings, read from the
sources. MEMBER-P is given the type as written, on one line."
  (let ((found '())
        (root (asdf:system-source-directory "coalton-geometry")))
    (dolist (path (append (directory (merge-pathnames "src/*.ct" root)) (directory (merge-pathnames "src/*/*.ct" root))))
      (let* ((text (substitute #\Space #\Return (uiop:read-file-string path :external-format :utf-8)))
             (package-start (+ (search "(cl:defpackage #:" text) (length "(cl:defpackage #:")))
             (package (subseq text package-start (position-if #'alias-whitespace-p text :start package-start)))
             (exported (alias-exported-names text)))
        (loop :with i := 0
              :for at := (search "(declare " text :start2 i)
              :while at
              :do (let* ((name-start (+ at (length "(declare ")))
                         (name-end (position-if #'alias-whitespace-p text :start name-start))
                         (name (subseq text name-start name-end))
                         (form (alias-balanced text at))
                         (type-text (string-trim " " (substitute #\Space #\Newline
                                                                 (subseq form (- name-end at) (1- (length form)))))))
                    (setf i (+ at (length form)))
                    (when (and (member name exported :test #'string=) (plusp (length type-text))
                               (char= (char type-text 0) #\() (funcall member-p type-text))
                      (push (format nil "~A:~A" package name) found))))))
    (sort found #'string<)))

(defun alias-inventory ()
  "The exported functions with two or more arrays among their own parameters."
  (source-inventory (lambda (type-text)
                      (<= 2 (count-if (lambda (parameter) (eql 0 (search "arr:LispArray" parameter)))
                                      (alias-parameters type-text))))))

;;; ---- The verdict on one call -------------------------------------------------------------

(defun alias-same-p (a b)
  (and (= (length a) (length b))
       (if (typep a '(simple-array double-float (*))) (same-bits-p a b) (equalp a b))))

(defun alias-run (call arrays)
  "The call's outcome as a code, 0 for success, and whatever further arrays it returned. A condition is a refusal."
  (handler-case (multiple-value-bind (code extras) (funcall call arrays)
                  (values (if (integerp code) code 0) extras))
    (error () (values 99 nil))))

(defun alias-pairs (arrays)
  "Every pair of positions holding arrays of one element type and one length: the pairs that can be one array."
  (loop :for i :from 0 :below (length arrays) :append
    (loop :for j :from (1+ i) :below (length arrays)
          :when (and (equal (array-element-type (nth i arrays)) (array-element-type (nth j arrays)))
                     (= (length (nth i arrays)) (length (nth j arrays))))
            :collect (list i j))))

(defun alias-verdict (label build call i j)
  "Call once with positions I and J holding two arrays of equal contents, and once with them holding one array.
:REFUSED when the second call refuses and leaves every array as it was; :SAME when it does what the first did.
Anything else is an error."
  (let* ((distinct (funcall build)) (shared (funcall build)))
    (setf (nth j distinct) (copy-seq (nth i distinct)))
    (setf (nth j shared) (nth i shared))
    (let ((before (mapcar #'copy-seq distinct)) (shared-before (mapcar #'copy-seq shared)))
      (multiple-value-bind (reference-code reference-extras) (alias-run call distinct)
        ;; The premise: with two arrays the call is one the library accepts. Without it a mistake in
        ;; an entry would read as a refusal.
        (assert (= 0 reference-code) ()
                "~A: the call with arguments ~D and ~D two equal arrays gives ~D; the entry is wrong." label i j
                reference-code)
        (multiple-value-bind (code extras) (alias-run call shared)
          (cond
            ((/= code 0)
             (loop :for array :in shared :for was :in shared-before :for position :from 0 :do
               (assert (alias-same-p array was) ()
                       "~A: with arguments ~D and ~D one array the call refused, code ~D, after writing argument ~D."
                       label i j code position))
             :refused)
            (t
             (let ((wrote-i (not (alias-same-p (nth i distinct) (nth i before))))
                   (wrote-j (not (alias-same-p (nth j distinct) (nth j before)))))
               (assert (not (and wrote-i wrote-j)) ()
                       "~A: arguments ~D and ~D are both written, and the call accepted them as one array." label i j)
               (loop :for position :from 0 :for array :in shared :for reference :in distinct :do
                 (let ((expected (cond ((and (= position i) wrote-j) (nth j distinct))
                                       ((and (= position j) wrote-i) (nth i distinct))
                                       (t reference))))
                   (assert (alias-same-p array expected) ()
                           "~A: with arguments ~D and ~D one array, argument ~D ends as ~S; with two equal arrays, ~S."
                           label i j position array expected)))
               (assert (and (= (length extras) (length reference-extras))
                            (every #'alias-same-p extras reference-extras))
                       () "~A: with arguments ~D and ~D one array the result differs." label i j))
             :same)))))))

;;; ---- The members -------------------------------------------------------------------------

(defun alias-roster ()
  "One entry for each member: its key, how to make its arrays afresh, how to call it on them, and the outcome
expected of each pair that can be one array. An entry of (key :exempt reason) has no test."
  (list
   ;; The parameters and the output are both arrays of doubles. The output is a whole block for
   ;; each parameter, so the two have one length only when there is no parameter at all; that is
   ;; the one case in which they can be one array, and the call refuses it.
   (list "coalton-geometry/spline/basis:evaluate-batch!"
         (lambda () (list (doubles) (indices) (doubles)))
         (let ((handle (basis:make-basis 2 (doubles 0d0 0d0 0d0 1d0 1d0 1d0) 1)))
           (lambda (a) (bc:batch-code handle (first a) 1 (second a) (third a))))
         '(((0 2) :refused)))
   ;; A segment in the plane to the first order: two control points, four rows, a point and a
   ;; derivative. All three arrays then have four entries, so every pair can be one array, and
   ;; each has an output in it.
   (list "coalton-geometry/spline/curve:evaluate!"
         (lambda () (list (doubles 0.25d0 0.5d0 0.75d0 1d0) (doubles 0d0 0d0 0d0 0d0) (doubles 0d0 0d0 0d0 0d0)))
         (let ((handle (basis:make-basis 1 (doubles 0d0 0d0 1d0 1d0) 1)))
           (lambda (a) (cc:evaluate-code handle (first a) 2 0.25d0 1 (second a) (third a))))
         '(((0 1) :refused) ((0 2) :refused) ((1 2) :refused)))
   ;; The same segment at four parameters. The control points and the parameters are both only
   ;; read, and here they have one length and can be one array: four numbers that are two points
   ;; and are also four parameters of the domain. The rows and the result have sixteen entries each.
   (list "coalton-geometry/spline/curve:evaluate-batch!"
         (lambda () (list (doubles 0.25d0 0.5d0 0.75d0 1d0) (doubles 0.25d0 0.5d0 0.75d0 1d0) (indices 9 9 9 9)
                          (make-array 16 :element-type 'double-float :initial-element 0d0)
                          (make-array 16 :element-type 'double-float :initial-element 0d0)))
         (let ((handle (basis:make-basis 1 (doubles 0d0 0d0 1d0 1d0) 1)))
           (lambda (a) (cc:batch-code handle (first a) 2 (second a) 1 (third a) (fourth a) (fifth a))))
         '(((0 1) :same) ((3 4) :refused)))))

(defun alias-missing (inventory keys)
  "Members of the inventory the roster does not name, and names in the roster that are not members."
  (values (set-difference inventory keys :test #'string=) (set-difference keys inventory :test #'string=)))

(defun alias-check-entry (entry)
  "Run every pair of one entry and compare with what it declares. Returns the outcomes as a list of (pair outcome)."
  (destructuring-bind (key build call expected) entry
    (assert (= 0 (alias-run call (funcall build))) () "~A: the entry's own call is refused." key)
    (let* ((pairs (alias-pairs (funcall build)))
           (outcomes (loop :for (i j) :in pairs :collect (list (list i j) (alias-verdict key build call i j)))))
      (assert (equal outcomes expected) ()
              "~A: the pairs that can be one array behave as ~S; the roster declares ~S." key outcomes expected)
      outcomes)))

(defun run-aliasing-tests ()
  (let* ((roster (alias-roster)) (inventory (alias-inventory)) (keys (mapcar #'first roster))
         (same 0) (refused 0) (exempt 0) (without-pair 0))
    ;; The roster names every member the sources have, and nothing else.
    (multiple-value-bind (unanswered unknown) (alias-missing inventory keys)
      (assert (null unanswered) () "Calls that take two or more arrays and have no entry in the aliasing roster: ~S."
              unanswered)
      (assert (null unknown) () "Entries of the aliasing roster that name no such call: ~S." unknown))
    ;; Control: a call the sources would add is reported until it is answered for.
    (assert (equal '("coalton-geometry/new:call!") (alias-missing (cons "coalton-geometry/new:call!" inventory) keys)))
    (dolist (entry roster)
      (cond
        ((eq (second entry) :exempt) (incf exempt))
        (t
         (let ((outcomes (alias-check-entry entry)))
           (when (null outcomes) (incf without-pair))
           (incf same (count :same outcomes :key #'second))
           (incf refused (count :refused outcomes :key #'second))))))
    ;; Controls for the verdict itself: a call that reads what it has already overwritten, and
    ;; a refusal that comes after a write, are both reported.
    (flet ((reported-p (call)
             (handler-case (progn (alias-verdict "control" (lambda () (list (doubles 1d0 2d0 3d0) (doubles 0d0 0d0 0d0)))
                                                 call 0 1)
                                  nil)
               (error () t))))
      (assert (reported-p (lambda (a)
                            ;; out[i] = in[i - 1] + in[i]: right with two arrays, wrong with one.
                            (let ((in (first a)) (out (second a)))
                              (dotimes (i 3) (setf (aref out i) (+ (aref in i) (if (plusp i) (aref in (1- i)) 0d0)))))
                            0))
              () "The verdict accepted a call that reads what it has overwritten.")
      (assert (reported-p (lambda (a)
                            (setf (aref (second a) 0) 42d0)
                            (if (eq (first a) (second a)) 9 0)))
              () "The verdict accepted a refusal that came after a write.")
      (assert (not (reported-p (lambda (a) (replace (second a) (first a)) 0)))
              () "The verdict reported a call that is right with one array."))
    (format t "ALIASING-ROSTER-PASS calls=~D exempt=~D without-a-pair=~D pairs-same=~D pairs-refused=~D~%"
            (length roster) exempt without-pair same refused)))
