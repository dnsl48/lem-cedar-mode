(defpackage :lem-cedar-mode/lsp-config
  (:use :cl)
  (:import-from :lem-lsp-mode
                :define-language-spec)
  (:import-from :lem-lsp-mode/spec
                :spec-command)
  (:export :*language-server-command*
           :*language-server-directory*))
(in-package :lem-cedar-mode/lsp-config)

(defvar *language-server-command* '("cedar-language-server")
  "Command line that starts the Cedar language server on stdio.")

(defvar *language-server-directory* (uiop:xdg-cache-home "lem-cedar-mode/")
  "Working directory for the language server, created on demand.
cedar-language-server writes ./logs/ into whatever directory it starts in, and
Lem starts servers in its own working directory.  NIL runs it there anyway.")

(define-language-spec (cedar-spec lem-cedar-mode:cedar-mode)
  :language-id "cedar"
  :root-uri-patterns '()
  :install-command "cargo install --locked --git https://github.com/cedar-policy/cedar cedar-language-server"
  :readme-url "https://github.com/cedar-policy/cedar/tree/main/cedar-language-server"
  :connection-mode :stdio)

(defmethod spec-command ((spec cedar-spec))
  (let ((command *language-server-command*)
        (directory *language-server-directory*))
    ;; A missing server stays unwrapped: lsp-mode checks the first word of the
    ;; command and, for "sh", would never show its install hint.
    (if (and directory (lem:exist-program-p (first command)))
        `("sh" "-c" "cd \"$0\" && exec \"$@\""
               ,(namestring (ensure-directories-exist directory))
               ,@command)
        command)))
