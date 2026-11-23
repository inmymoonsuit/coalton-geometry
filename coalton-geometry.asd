(asdf:defsystem "coalton-geometry"
  :description "Geometry in Coalton. Reserved: no module is built yet; see ROADMAP.md."
  :version "0.0.1"
  :license "MIT"
  :defsystem-depends-on ("coalton-asdf")
  :depends-on ("coalton")
  :in-order-to ((asdf:test-op (asdf:test-op "coalton-geometry/tests")))
  :around-compile
  (lambda (compile)
    (let ((sb-ext:*derive-function-types* t)
          (sb-ext:*block-compile-default* :specified))
      (funcall compile)))
  ;; No component is declared until a module has a contract and a consumer. A module is added
  ;; here as a :ct-file under a "src" module, and the two rosters then read it from the sources.
  :components ())

(asdf:defsystem "coalton-geometry/tests"
  :description "The checks that hold before any module exists: the toolchain compiles Coalton, the rosters read the sources, and how a point can be stored is measured."
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
                             (:file "aliasing") (:file "scale-sweep")
                             (:file "suite"))))
  :perform (asdf:test-op (operation system)
             (declare (ignore operation system))
             (uiop:symbol-call :coalton-geometry/tests :run-tests)))
