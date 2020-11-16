PACKAGE_NAME := awscli-login

PKG  := src/awscli_login
TPKG := src/tests
MODULE_SRCS := $(wildcard $(PKG)/*.py)
export TSTS := $(wildcard $(TPKG)/*.py $(TPKG)/*/*.py)
export SRCS := $(wildcard $(MODULE_SRCS) setup.py)
HTML = htmlcov/index.html
TOX_ENV := .tox/wheel/pyvenv.cfg
TOX_DEV := .tox/develop/pyvenv.cfg
TOX_LINT := .lint
TOX_STATIC := .static
WHEEL = $(wildcard dist/*.whl)
RELEASE = $(filter %.whl %.tar.gz, $(wildcard dist/$(PACKAGE_NAME)-[0-9]*))
PIP = python -m pip install --upgrade --upgrade-strategy eager

.PHONY: all install test lint static develop develop-test
.PHONY: freeze shell clean docs coverage doctest

all: install test coverage docs doctest

# Python dependencies needed for local development
deps: deps-build deps-doc deps-local deps-test deps-publish

# Python packages needed to run the tests on a Unix system
deps-posix: deps
	$(PIP) tox-pyenv

# Python packages needed to build a wheel
deps-build:
	$(PIP) setuptools tox wheel

# Python packages needed to build the documentation
deps-doc:
	$(PIP) Sphinx sphinx-autodoc-typehints sphinx_rtd_theme

# Python packages needed to build a local production or test release
deps-local:
	$(PIP) GitPython

# Python packages needed to run tests
deps-test: deps-build

# Python packages needed to publish a production or test release
deps-publish:
	$(PIP) twine

# Install wheel into tox virtualenv for testing
install: $(TOX_ENV)
$(TOX_ENV): build | cache
	tox -e wheel --notest --installpkg $(WHEEL) -vv
	@touch $@

# Build wheel and source tarball for upload to PyPI
build: $(SRCS)
	python setup.py sdist bdist_wheel
	@touch $@

# Build and save dependencies for reuse
# https://packaging.python.org/guides/index-mirrors-and-caches/#caching-with-pip
# https://www.gnu.org/software/make/manual/make.html#Prerequisite-Types
cache: setup.py | build
	pip wheel --wheel-dir=$@ $(WHEEL) $(WHEEL)[test] coverage
	@touch $@

.python-version:
	pyenv install -s 3.5.10
	pyenv install -s 3.6.12
	pyenv install -s 3.7.9
	pyenv install -s 3.8.6
	pyenv install -s 3.9.0
	pyenv local 3.5.10 3.6.12 3.7.9 3.8.6 3.9.0

# Run tests on multiple versions of Python (POSIX only)
tox: .python-version build | cache
	tox --installpkg $(WHEEL)

# Run tests against wheel installed in virtualenv
test: lint static .coverage
.coverage: $(TOX_ENV) $(TSTS)
	tox -e wheel --skip-pkg-install -qq
	@touch $@

# Show coverage report
coverage: .coverage
	tox -e coverage --skip-pkg-install -qq

# Run tests directly against source code in develop mode
develop: lint static .develop-test coverage

.develop-test: $(TOX_DEV) $(MODULE_SRCS) $(TSTS)
	tox -e develop --skip-pkg-install -qq
	@touch $@

# Build develop virtualenv and install module & deps so that changes
# to source files will show up in the virtualenv without the need
# to rebuild and install.
$(TOX_DEV): setup.py
	tox -e develop  --notest
	@touch $@

lint: $(TOX_LINT)
$(TOX_LINT): $(SRCS) $(TSTS)
	tox -e lint -qq
	@touch $@

static: $(TOX_STATIC)
$(TOX_STATIC):$(SRCS) $(TSTS)
	tox -e static -qq
	@touch $@

freeze: $(TOX_ENV)
	tox -e wheel --skip-pkg-install -- pip freeze

shell: $(TOX_ENV)
	tox -e wheel --skip-pkg-install -qq -- bash

report: $(HTML)
$(HTML): .coverage
	tox -e report --skip-pkg-install -qq

docs: $(SRCS) $(TSTS)
	make -C docs html

doctest: $(SRCS) $(TSTS)
	make -C docs doctest

TST := Please build a test release!
test-release: TWINE_REPOSITORY ?= testpypi
test-release: build
	@echo "$(RELEASE)" | python -c \
        "import sys; \
        [print('$(TST)') or exit(1) for l in sys.stdin if 'dev' not in l]"
	TWINE_REPOSITORY=$(TWINE_REPOSITORY) twine upload "$(RELEASE)"

MSG := Please tag & build a production release!
release: build
	@echo "$(RELEASE)" | python -c \
        "import sys; \
        [print('$(MSG)') or exit(1) for l in sys.stdin if 'dev' in l]"
	twine upload "$(RELEASE)"

clean:
	rm -rf .coverage .develop-test .lint  .mypy_cache .static .tox .wheel htmlcov
	rm -rf $(PKG)/__pycache__ $(TPKG)/__pycache__ $(TPKG)/cli/__pycache__/ $(TPKG)/config/__pycache__
	rm -rf build dist src/*.egg-info .eggs
	make -C docs clean

clean-all: clean
	rm -rf cache
