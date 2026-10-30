;; The main system declares no Lem dependencies on purpose.  It is meant to be
;; loaded into a running Lem, where Lem's systems are already present.  Naming
;; them here would make ASDF re-check (and possibly recompile) Lem's sources
;; whenever the checkout a binary was built from has moved on since the build.
(defsystem "lem-cedar-mode"
  :description "Cedar major mode for Lem"
  :author "Serge Latyntsev"
  :license "MIT"
  :version "0.1.0"
  :pathname "src"
  :serial t
  :components ((:file "cedar-mode")
               (:file "lsp-config"))
  :in-order-to ((test-op (test-op "lem-cedar-mode/tests"))))

(defsystem "lem-cedar-mode/tests"
  :depends-on ("lem/core"
               "lem-lsp-mode"
               "lem-cedar-mode"
               "rove")
  :pathname "tests"
  :components ((:file "cedar-mode"))
  :perform (test-op (o c) (symbol-call :rove :run c)))
