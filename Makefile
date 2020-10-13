default: all

SRC = $(wildcard src/*.mamba | sort)
LIB = $(SRC:src/%.mamba=lib/%.js) lib/parser.js
BOOTSTRAPS = $(SRC:src/%.mamba=lib/bootstrap/%.js) lib/bootstrap/parser.js
LIBMIN = $(LIB:lib/%.js=lib/%.min.js)
TEST = $(wildcard test/*.mamba | sort)
ROOT = $(shell pwd)

KOFU = bin/mambascript --js --bare --self
PEGJS = node_modules/.bin/pegjs --cache --export-var 'module.exports'
MOCHA = node_modules/.bin/mocha --require ./register -u test
CJSIFY = node_modules/.bin/cjsify --export MambaScript
MINIFIER = node_modules/.bin/esmangle

all: $(LIB)
build: all
parser: lib/parser.js
browser: dist/mambascript.min.js
min: minify
minify: $(LIBMIN)
# TODO: test-browser
# TODO: doc
# TODO: bench


lib:
	mkdir lib/
lib/bootstrap: lib
	mkdir -p lib/bootstrap


lib/parser.js: src/grammar.pegjs bootstraps lib
	$(PEGJS) <"$<" >"$@.tmp" && mv "$@.tmp" "$@"
lib/bootstrap/parser.js: src/grammar.pegjs lib/bootstrap
	$(PEGJS) <"$<" >"$@"
lib/bootstrap/%.js: src/%.mamba lib/bootstrap
	$(KOFU) -i "$<" >"$@"
bootstraps: $(BOOTSTRAPS) lib/bootstrap
	cp lib/bootstrap/* lib
lib/%.js: src/%.mamba lib/bootstrap/%.js bootstraps lib
	$(KOFU) -i "$<" >"$@.tmp" && mv "$@.tmp" "$@"


dist:
	mkdir dist/

dist/mambascript.js: lib/browser.js dist
	$(CJSIFY) src/browser.mamba -vx MambaScript \
		-a /src/register.mamba: \
		-a /src/parser.mamba:/lib/parser.js \
		--source-map "$@.map" > "$@"

dist/mambascript.min.js: lib/browser.js dist
	$(CJSIFY) src/browser.mamba -vmx MambaScript \
		-a /src/register.mamba: \
		-a /src/parser.mamba:/lib/parser.js \
		--source-map "$@.map" > "$@"


lib/%.min.js: lib/%.js lib/mambascript
	$(MINIFIER) <"$<" >"$@"


.PHONY: default all build parser browser min minify test coverage install loc clean

test:
	$(MOCHA) "test/*.coffee"

# TODO: use Constellation/ibrik for coverage
coverage:
	@which jscoverage || (echo "install node-jscoverage"; exit 1)
	rm -rf instrumented
	jscoverage -v lib instrumented
	$(MOCHA) -R dot
	$(MOCHA) -r instrumented/compiler -R html-cov > coverage.html
	@xdg-open coverage.html &> /dev/null

install:
	npm install -g .

loc:
	wc -l src/*

clean:
	rm -rf instrumented
	rm -f coverage.html
	rm -rf lib
	rm -rf dist
