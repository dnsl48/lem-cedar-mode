(defpackage :lem-cedar-mode/tests
  (:use :cl :rove :lem)
  (:import-from :lem-cedar-mode
                :cedar-mode
                :*cedar-syntax-table*
                :calc-indent)
  (:import-from :lem-cedar-mode/lsp-config
                :*language-server-command*
                :*language-server-directory*)
  (:import-from :lem-lsp-mode/spec
                :get-language-spec
                :spec-language-id
                :spec-connection-mode
                :spec-command))
(in-package :lem-cedar-mode/tests)

;;;; Helpers

(defmacro with-cedar-buffer ((buffer content) &body body)
  "Run BODY with BUFFER in cedar-mode holding CONTENT, without starting a server."
  `(with-current-buffers ()
     (let ((,buffer (make-buffer "*cedar-test*" :temporary t :enable-undo-p nil)))
       (lem-lsp-mode:without-lsp-mode ()
         (change-buffer-mode ,buffer 'cedar-mode))
       (insert-string (buffer-point ,buffer) ,content)
       ,@body)))

(defun read-example (name)
  (uiop:read-file-string
   (asdf:system-relative-pathname "lem-cedar-mode" (format nil "examples/~A" name))))

(defun strip-indentation (text)
  (format nil "~{~A~^~%~}"
          (mapcar (lambda (line) (string-left-trim '(#\Space #\Tab) line))
                  (uiop:split-string text :separator '(#\Newline)))))

(defun reindent (text)
  "Strip TEXT's indentation, then indent it line by line as Lem would."
  (with-cedar-buffer (buffer (strip-indentation text))
    (with-point ((p (buffer-start-point buffer)))
      (loop :do (unless (blank-line-p p)
                  (indent-line p))
            :while (line-offset p 1)))
    (buffer-text buffer)))

(defun attribute-of (text needle &key (occurrence 1))
  "Highlight attribute on the first character of the OCCURRENCE-th NEEDLE in TEXT."
  (with-cedar-buffer (buffer text)
    (syntax-scan-region (buffer-start-point buffer) (buffer-end-point buffer))
    (with-point ((p (buffer-start-point buffer)))
      (loop :repeat occurrence
            :do (unless (search-forward p needle)
                  (error "~S not found in ~S" needle text)))
      (character-offset p (- (length needle)))
      (text-property-at p :attribute))))

;;;; Mode and file types

(deftest cedar-mode-is-a-named-major-mode
  (ok (string= "Cedar" (mode-name 'cedar-mode))))

(deftest cedar-mode-indents-like-the-official-formatter
  (with-cedar-buffer (buffer "")
    (ok (eql 4 (variable-value 'tab-width :buffer buffer)))
    (ng (variable-value 'indent-tabs-mode :buffer buffer))
    (ok (eq 'calc-indent (variable-value 'calc-indent-function :buffer buffer)))))

(deftest policy-and-schema-files-open-in-cedar-mode
  (ok (eq 'cedar-mode (get-file-mode "policies.cedar")))
  (ok (eq 'cedar-mode (get-file-mode "/tmp/app/schema.cedarschema")))
  (testing "JSON schema and entity files stay out of cedar-mode"
    (ng (eq 'cedar-mode (get-file-mode "schema.cedarschema.json")))
    (ng (eq 'cedar-mode (get-file-mode "entities.cedarentities.json")))))

;;;; Highlighting

(deftest policy-structure-is-highlighted
  (let ((policy "@id(\"p1\")
permit (principal == User::\"alice\", action, resource)
when { context.authenticated == true }
unless { resource.private };"))
    (ok (eq 'syntax-keyword-attribute (attribute-of policy "permit")))
    (ok (eq 'syntax-keyword-attribute (attribute-of policy "when")))
    (ok (eq 'syntax-keyword-attribute (attribute-of policy "unless")))
    (ok (eq 'syntax-variable-attribute (attribute-of policy "principal")))
    (ok (eq 'syntax-variable-attribute (attribute-of policy "action")))
    (ok (eq 'syntax-variable-attribute (attribute-of policy "context")))
    (ok (eq 'syntax-builtin-attribute (attribute-of policy "@id")))
    (ok (eq 'syntax-type-attribute (attribute-of policy "User")))
    (ok (eq 'syntax-string-attribute (attribute-of policy "\"alice\"")))
    (ok (eq 'syntax-constant-attribute (attribute-of policy "true")))))

(deftest expressions-are-highlighted
  (let ((policy "forbid (principal, action, resource)
when { resource has owner && resource.tags.contains(\"x\") }
unless { principal.age >= 18 || context.ip.isInRange(ip(\"10.0.0.0/8\")) };"))
    (ok (eq 'syntax-keyword-attribute (attribute-of policy "forbid")))
    (ok (eq 'syntax-keyword-attribute (attribute-of policy "has")))
    (ok (eq 'syntax-function-name-attribute (attribute-of policy "contains")))
    (ok (eq 'syntax-function-name-attribute (attribute-of policy "isInRange")))
    (ok (eq 'syntax-function-name-attribute (attribute-of policy "ip(")))
    (ok (eq 'syntax-constant-attribute (attribute-of policy "18")))))

(deftest template-slots-are-variables
  (let ((policy "permit (principal == ?principal, action, resource in ?resource);"))
    (ok (eq 'syntax-variable-attribute (attribute-of policy "?principal")))
    (ok (eq 'syntax-variable-attribute (attribute-of policy "?resource")))))

(deftest keywords-only-match-whole-words
  (let ((policy "permit (principal, action, resource)
when { resource.permitted && context.isAdmin && resource.type == \"x\" };"))
    (ng (attribute-of policy "permitted"))
    (ng (attribute-of policy "isAdmin"))
    (testing "an attribute named like a keyword is not a keyword"
      (ng (attribute-of policy "type")))))

(deftest comments-and-strings-hide-keywords
  (let ((policy "// permit everything? no.
permit (principal, action, resource == Doc::\"when in doubt\");"))
    (ok (eq 'syntax-comment-attribute (attribute-of policy "permit")))
    (ok (eq 'syntax-keyword-attribute (attribute-of policy "permit" :occurrence 2)))
    (ok (eq 'syntax-string-attribute (attribute-of policy "when")))))

(deftest schema-declarations-are-highlighted
  (let ((schema "namespace PhotoApp {
  entity User in [Group] { age: Long } tags String;
  action \"view\" appliesTo { principal: [User], resource: Photo };
}"))
    (ok (eq 'syntax-keyword-attribute (attribute-of schema "namespace")))
    (ok (eq 'syntax-keyword-attribute (attribute-of schema "entity")))
    (ok (eq 'syntax-keyword-attribute (attribute-of schema "appliesTo")))
    (ok (eq 'syntax-keyword-attribute (attribute-of schema "tags")))
    (ok (eq 'syntax-type-attribute (attribute-of schema "PhotoApp")))
    (ok (eq 'syntax-type-attribute (attribute-of schema "Long")))))

;;;; Indentation

(deftest example-policies-keep-their-formatter-layout
  ;; photo-app.cedar is verbatim lsp-document-format output from
  ;; cedar-language-server, so this checks indenting agrees with the formatter.
  (let ((text (read-example "photo-app.cedar")))
    (ok (string= text (reindent text)))))

(deftest example-schema-keeps-its-indentation
  (let ((text (read-example "photo-app.cedarschema")))
    (ok (string= text (reindent text)))))

(deftest closers-line-up-with-their-opening-line
  (let ((text "namespace App {
    entity User {
        tags: Set<String>,
    };
}
forbid (principal, action, resource)
when {
    resource.private
};"))
    (ok (string= text (reindent text)))))

(deftest brackets-in-strings-and-comments-are-ignored
  (let ((text "// a { that never closes
permit (
    principal,
    action,
    resource == Doc::\"(\"
);
forbid (principal, action, resource);"))
    (ok (string= text (reindent text)))))

;;;; Language server

(deftest language-server-spec-is-registered
  (let ((spec (get-language-spec 'cedar-mode)))
    (ok spec)
    (ok (string= "cedar" (spec-language-id spec)))
    (ok (eq :stdio (spec-connection-mode spec)))))

(deftest missing-server-command-is-returned-unwrapped
  (testing "so lsp-mode can report the missing program with its install hint"
    (let ((*language-server-command* '("cedar-language-server-that-does-not-exist"))
          (*language-server-directory* (uiop:temporary-directory)))
      (ok (equal *language-server-command*
                 (spec-command (get-language-spec 'cedar-mode)))))))

(deftest server-runs-without-wrapper-when-directory-is-nil
  (let ((*language-server-command* '("sh"))
        (*language-server-directory* nil))
    (ok (equal '("sh") (spec-command (get-language-spec 'cedar-mode))))))

(deftest server-runs-in-the-configured-directory
  (let* ((directory (uiop:ensure-directory-pathname
                     (merge-pathnames (format nil "lem-cedar-mode-test-~36R/" (random (expt 36 8)))
                                      (uiop:temporary-directory))))
         (*language-server-command* '("pwd"))
         (*language-server-directory* directory))
    (unwind-protect
         (let ((command (spec-command (get-language-spec 'cedar-mode))))
           (ok (uiop:directory-exists-p directory) "the directory is created on demand")
           (ok (string= (namestring (truename directory))
                        (namestring
                         (uiop:ensure-directory-pathname
                          (string-right-trim '(#\Newline)
                                             (uiop:run-program command :output :string)))))))
      (uiop:delete-directory-tree directory :validate t :if-does-not-exist :ignore))))
