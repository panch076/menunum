PREFIX ?= /usr/local

build:
	swift build -c release

install: build
	install -d $(PREFIX)/bin
	install .build/release/menunum $(PREFIX)/bin/menunum

uninstall:
	-$(PREFIX)/bin/menunum quit
	rm -f $(PREFIX)/bin/menunum

.PHONY: build install uninstall
