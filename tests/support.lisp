(defpackage #:coalton-geometry/tests
  (:use #:cl)
  (:export #:run-tests))
(in-package #:coalton-geometry/tests)

;;; What every test file here uses. Nothing in it is about geometry.

(defun indices (&rest contents)
  (make-array (length contents) :element-type '(unsigned-byte 62) :initial-contents contents))

(defun doubles (&rest contents)
  (make-array (length contents) :element-type 'double-float :initial-contents contents))

(defun same-bits-p (left right)
  "Two arrays of doubles with the same bits in every entry: a zero is not its negative, and a NaN is itself."
  (and (= (length left) (length right))
       (loop :for a :across left :for b :across right
             :always (and (= (sb-kernel:double-float-high-bits a) (sb-kernel:double-float-high-bits b))
                          (= (sb-kernel:double-float-low-bits a) (sb-kernel:double-float-low-bits b))))))

(defun bytes-a-call (run &optional (count 100000))
  "RUN takes a count and makes that many calls inside one compiled loop. Returns the bytes allocated for each call,
to the nearest byte, after a warm-up of a thousand. Meaningful only with the finalizer paused, as the check runner
does."
  (funcall run 1000)
  (sb-ext:gc :full t)
  (let ((before (sb-ext:get-bytes-consed)))
    (funcall run count)
    (round (- (sb-ext:get-bytes-consed) before) count)))

(defvar *allocation-control* nil)

(defun allocation-control-test ()
  "The measurement sees an allocation: a loop that makes one cons a call is not reported as none."
  (let ((bytes (bytes-a-call (lambda (count) (dotimes (i count) (setf *allocation-control* (cons i i)))))))
    (assert (= 16 bytes) () "A cons a call measured as ~D bytes a call, not 16." bytes)
    (format t "ALLOCATION-CONTROL-PASS bytes-a-cons=~D~%" bytes)))
