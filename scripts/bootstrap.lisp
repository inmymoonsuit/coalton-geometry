(require :asdf)
(unless (and (member :sbcl *features*) (= most-positive-fixnum (1- (expt 2 62))))
  (error "This library targets 64-bit SBCL."))

(defparameter *library-root*
  (uiop:pathname-parent-directory-pathname
    (uiop:pathname-directory-pathname *load-truename*)))

(load (merge-pathnames "scripts/register-dependencies.lisp" *library-root*))

(let ((safety (uiop:getenv "COALTON_GEOMETRY_SAFETY")))
  (unless (member safety '("0" "1") :test #'equal)
    (error "COALTON_GEOMETRY_SAFETY must be 0 or 1."))
  (when (equal safety "0") (pushnew :coalton-geometry-safety-zero *features*)))

(asdf:load-system "coalton")
(asdf:load-asd (merge-pathnames "coalton-geometry.asd" *library-root*))

(defun load-refusing-warnings (system)
  "Load a system afresh and fail if the compiler warned. The Coalton compiler handles its own warnings and the build
goes on, so they are recognized in what it prints. Safety is a reader feature: never reuse a FASL from the other
policy, hence the forced rebuild."
  (let* ((printed (make-string-output-stream))
         (*error-output* (make-broadcast-stream *error-output* printed)))
    (asdf:load-system system :force t)
    (when (search "caught WARNING" (get-output-stream-string printed))
      (error "The compiler warned while building ~A; see its output above." system))))

(load-refusing-warnings "coalton-geometry")
(format t "TOOLCHAIN SBCL=~A COALTON_ENV=~A safety=~A~%"
        (lisp-implementation-version) (uiop:getenv "COALTON_ENV")
        (uiop:getenv "COALTON_GEOMETRY_SAFETY"))
