default: all

SRC = $(wildcard src/*.kofu | sort)
LIB = $(SRC:src/%.kofu=lib/%.js) lib/parser.js
BOOTSTRAPS = $(SRC:src/%.kofu=lib/bootstrap/%.js) lib/bootstrap/parser.js
LIBMIN = $(LIB:lib/%.js=lib/%.min.js)
TEST = $(wildcard test/*.kofu | sort)
ROOT = $(shell pwd)

KOFU = bin/kofuscript --js --bare --self
PEGJS = node_modules/.bin/pegjs --cache --export-var 'module.exports'
MOCHA = node_modules/.bin/mocha --self --compilers coffee:./register -u tdd
CJSIFY = node_modules/.bin/cjsify --export KofuScript
MINIFIER = node_modules/.bin/esmangle

all: $(LIB)
build: all
parser: lib/parser.js
browser: dist/kofuscript.min.js
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
lib/bootstrap/%.js: src/%.kofu lib/bootstrap
	$(KOFU) -i "$<" >"$@"
bootstraps: $(BOOTSTRAPS) lib/bootstrap
	cp lib/bootstrap/* lib
lib/%.js: src/%.kofu lib/bootstrap/%.js bootstraps lib
	$(KOFU) -i "$<" >"$@.tmp" && mv "$@.tmp" "$@"


dist:
	mkdir dist/

dist/kofuscript.js: lib/browser.js dist
	$(CJSIFY) src/browser.kofu -vx KofuScript \
		-a /src/register.kofu: \
		-a /src/parser.kofu:/lib/parser.js \
		--source-map "$@.map" > "$@"

dist/kofuscript.min.js: lib/browser.js dist
	$(CJSIFY) src/browser.kofu -vmx KofuScript \
		-a /src/register.kofu: \
		-a /src/parser.kofu:/lib/parser.js \
		--source-map "$@.map" > "$@"


lib/%.min.js: lib/%.js lib/kofuscript
	$(MINIFIER) <"$<" >"$@"


.PHONY: default all build parser browser min minify test coverage install loc clean

test:
	$(MOCHA) -R dot test/*.kofu

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
