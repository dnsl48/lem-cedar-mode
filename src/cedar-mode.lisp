(defpackage :lem-cedar-mode
  (:use :cl
        :lem
        :lem/language-mode
        :lem/language-mode-tools)
  (:export :cedar-mode
           :*cedar-mode-hook*
           :*cedar-mode-keymap*
           :*cedar-syntax-table*
           :calc-indent
           :cedar-insert-closer))
(in-package :lem-cedar-mode)

;;;; Highlighting

(defvar *keywords*
  '("permit" "forbid" "when" "unless" "if" "then" "else" "in" "has" "like" "is"
    "namespace" "entity" "type" "appliesTo" "tags" "enum")
  "Policy and schema keywords.")

(defvar *variables*
  '("principal" "action" "resource" "context")
  "Request variables.  They also head schema declarations and appliesTo keys.")

(defvar *constants*
  '("true" "false"))

(defun words (strings)
  "Match any of STRINGS as a whole word that is not an attribute after a dot."
  `(:sequence (:negative-lookbehind #\.)
              :word-boundary
              (:alternation ,@(sort (copy-list strings) #'> :key #'length))
              :word-boundary))

(defun make-tmlanguage-cedar ()
  ;; On a tie the earliest, then longest, then first-listed pattern wins, so
  ;; keywords must come before the generic call pattern at the end.
  (make-tmlanguage
   :patterns (make-tm-patterns
              (make-tm-line-comment-region "//")
              (make-tm-string-region "\"")
              (make-tm-match "@[A-Za-z_][A-Za-z0-9_]*"
                             :name 'syntax-builtin-attribute)
              (make-tm-match "\\?(?:principal|resource)\\b"
                             :name 'syntax-variable-attribute)
              (make-tm-match (words *keywords*)
                             :name 'syntax-keyword-attribute)
              (make-tm-match (words *variables*)
                             :name 'syntax-variable-attribute)
              (make-tm-match (words *constants*)
                             :name 'syntax-constant-attribute)
              (make-tm-match "\\b[0-9]+\\b"
                             :name 'syntax-constant-attribute)
              ;; Entity type paths (PhotoApp::User::"alice") and type names.
              (make-tm-match "\\b[A-Za-z_][A-Za-z0-9_]*(?=::)"
                             :name 'syntax-type-attribute)
              (make-tm-match "\\b[A-Z][A-Za-z0-9_]*\\b"
                             :name 'syntax-type-attribute)
              ;; Extension functions and methods: ip("..."), .contains(...)
              (make-tm-match "\\b[A-Za-z_][A-Za-z0-9_]*(?=\\s*\\()"
                             :name 'syntax-function-name-attribute))))

(defvar *cedar-syntax-table*
  (let ((table (make-syntax-table
                :space-chars '(#\space #\tab #\newline)
                :symbol-chars '(#\_)
                :paren-pairs '((#\( . #\))
                               (#\[ . #\])
                               (#\{ . #\}))
                :string-quote-chars '(#\")
                :line-comment-string "//")))
    (set-syntax-parser table (make-tmlanguage-cedar))
    table))

;;;; Indentation

(defun calc-indent (point)
  "Indent one TAB-WIDTH step past the line that opens the innermost enclosing
bracket.  A line starting with a closing bracket lines up with that line.
Lines inside a string are left alone."
  (with-point ((p point))
    (back-to-indentation p)
    (unless (in-string-p p)
      (with-point ((opener p))
        (cond ((not (scan-lists opener -1 1 t))
               0)
              ((member (character-at p) '(#\) #\] #\}))
               (point-column (back-to-indentation opener)))
              (t
               (+ (point-column (back-to-indentation opener))
                  (variable-value 'tab-width :default point))))))))

(define-command cedar-insert-closer (n) (:universal)
  "Insert the typed closing bracket and re-indent the current line."
  (self-insert n)
  (indent-line (current-point)))

;;;; Mode

(define-major-mode cedar-mode language-mode
    (:name "Cedar"
     :keymap *cedar-mode-keymap*
     :syntax-table *cedar-syntax-table*
     :mode-hook *cedar-mode-hook*)
  (setf (variable-value 'enable-syntax-highlight) t
        (variable-value 'indent-tabs-mode) nil
        (variable-value 'tab-width) 2
        (variable-value 'calc-indent-function) 'calc-indent
        (variable-value 'line-comment) "//"
        (variable-value 'insertion-line-comment) "// "))

(define-key *cedar-mode-keymap* ")" 'cedar-insert-closer)
(define-key *cedar-mode-keymap* "]" 'cedar-insert-closer)
(define-key *cedar-mode-keymap* "}" 'cedar-insert-closer)

(define-file-type ("cedar" "cedarschema") cedar-mode)
