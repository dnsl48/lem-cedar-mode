# Tests need Lem's own systems, so they run inside a Lem checkout's qlot
# environment.  Point LEM_DIR at any checkout that has run `qlot install`.
LEM_DIR ?= ../curses
LISP ?= sbcl

.PHONY: test
test:
	cd "$(LEM_DIR)" && $(LISP) --noinform --non-interactive \
		--load .qlot/setup.lisp \
		--eval '(asdf:load-asd #p"$(CURDIR)/lem-cedar-mode.asd")' \
		--eval '(asdf:load-system "rove")' \
		--eval '(uiop:quit (if (uiop:symbol-call :rove :run "lem-cedar-mode/tests") 0 1))'
