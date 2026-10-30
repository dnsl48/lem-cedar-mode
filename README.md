# lem-cedar-mode

[Cedar](https://www.cedarpolicy.com/) policy language support for the
[Lem](https://github.com/lem-project/lem) editor:

- `cedar-mode` for `.cedar` policy files and `.cedarschema` schema files
- regex-based highlighting of keywords, request variables, template slots,
  annotations, entity types, strings, numbers, and extension function calls
- bracket-depth indentation, with closing brackets re-indented as you type them
- language server integration with the official
  [cedar-language-server](https://github.com/cedar-policy/cedar/tree/main/cedar-language-server)

## Language server

The server isn't on crates.io yet, so install it from the Cedar repository:

```sh
cargo install --locked --git https://github.com/cedar-policy/cedar cedar-language-server
```

`cedar-mode` turns on Lem's `lsp-mode` automatically. If the server isn't on
`PATH`, opening a Cedar file shows the install command above.

Through Lem's `lsp-mode` you get the features the server advertises:
diagnostics, completion, hover, go to definition, document symbols, rename,
code actions, and formatting (`M-x lsp-document-format`).

The server always writes `./logs/server.log` into its working directory, and
Lem starts servers in its own working directory. To keep `logs/` out of your
projects, `cedar-mode` starts the server from `~/.cache/lem-cedar-mode/`.

## Loading it

No custom Lem build is needed. Add this to `~/.config/lem/init.lisp`, adjusting
the path:

```lisp
(asdf:load-asd #p"/path/to/lem-cedar-mode/lem-cedar-mode.asd")
(asdf:load-system "lem-cedar-mode")
```

Once the repository is on a git host, Lem's extension manager can fetch it
instead (this needs a Lem build that includes Quicklisp):

```lisp
(lem-extension-manager:lem-use-package
 "lem-cedar-mode"
 :source (:type :git :url "https://example.com/you/lem-cedar-mode.git"))
```

The `lem-cedar-mode` system declares no dependencies on Lem's own systems on
purpose, because it is loaded into an already running Lem. If it declared them,
ASDF would re-check Lem's sources on load. When the checkout a binary was built
from has changed since the build, that can recompile parts of Lem inside your
running editor.

## Configuration

```lisp
;; Use a different server binary or extra arguments.
(setf lem-cedar-mode/lsp-config:*language-server-command*
      '("/opt/cedar/bin/cedar-language-server"))

;; Run the server in Lem's working directory instead of the cache directory.
(setf lem-cedar-mode/lsp-config:*language-server-directory* nil)

;; Highlighting and indentation only, without the language server.
(remove-hook lem-cedar-mode:*cedar-mode-hook* 'lem-lsp-mode/lsp-mode::enable-lsp-mode)
```

## Limitations

- **No schema association yet.** The server validates a policy file against a
  schema only after the editor sends `cedar.associateSchema`. The VS Code
  extension does that itself, but Lem's `lsp-mode` doesn't export a way to send
  custom commands. Without it you get syntax errors but no schema validation.
- `.cedarschema.json` and `.cedarentities.json` files open in Lem's JSON mode,
  and Lem attaches one language server per major mode, so they don't get the
  Cedar server.
- Indentation follows bracket depth only. It doesn't add extra indentation to
  continuation lines such as a wrapped `&&` expression. Use
  `lsp-document-format` for canonical layout.
- Highlighting is regex-based, not tree-sitter.

## Tests

The tests run inside a Lem checkout's qlot environment, because they need Lem's
own systems:

```sh
make test LEM_DIR=/path/to/lem    # defaults to ../curses
```

`examples/` holds a sample policy set and schema. The indentation tests check
that both files keep their exact layout when re-indented.

## License

MIT, see [LICENSE](LICENSE).
