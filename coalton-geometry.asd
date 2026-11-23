(asdf:defsystem "coalton-geometry"
  :description "Geometry in Coalton for a numerical solver: B-spline basis functions and their derivatives. See ROADMAP.md for what follows."
  :version "0.1.0"
  :license "MIT"
  :defsystem-depends-on ("coalton-asdf")
  :depends-on ("coalton")
  :in-order-to ((asdf:test-op (asdf:test-op "coalton-geometry/tests")))
  :around-compile
  (lambda (compile)
    (let ((sb-ext:*derive-function-types* t)
          (sb-ext:*block-compile-default* :specified))
      (funcall compile)))
  ;; A module is added here as a :ct-file once it has a contract and a consumer, and the two
  ;; rosters then read it from the sources.
  :components ((:module "src" :serial t
                :components ((:module "spline" :serial t
                              :components ((:ct-file "basis")))))))

(asdf:defsystem "coalton-geometry/tests"
  :description "Each module against its contract, the two rosters over every exported call, and how a point can be stored, measured."
  :depends-on ("coalton-geometry")
  :serial t
  :around-compile
  (lambda (compile)
    (let ((sb-ext:*derive-function-types* t)
          (sb-ext:*block-compile-default* :specified))
      (funcall compile)))
  :components ((:module "tests" :serial t
                :components ((:file "support")
                             (:ct-file "representation-subject") (:ct-file "representation-callers")
                             (:file "representation")
                             (:ct-file "spline-basis-callers") (:file "spline-basis")
                             (:file "aliasing") (:file "scale-sweep")
                             (:file "suite"))))
  :perform (asdf:test-op (operation system)
             (declare (ignore operation system))
             (uiop:symbol-call :coalton-geometry/tests :run-tests)))
