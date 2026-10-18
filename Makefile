.RECIPEPREFIX := >
SHELL := bash
LIB   := lib/proj
ORDER := core/config.sh core/util.sh core/tags.sh store/readme.sh store/state.sh \
         nav/resolve.sh store/scan.sh store/size.sh backup/backup.sh backup/clean.sh \
         cmd/new.sh cmd/add.sh cmd/remove.sh cmd/flags.sh cmd/mv.sh cmd/archive.sh cmd/vendor.sh \
         cmd/organize.sh cmd/list.sh cmd/info.sh cmd/notes.sh cmd/misc.sh cmd/doctor.sh \
         cmd/ui.sh cmd/pick.sh cmd/help.sh main.sh completion.sh

.PHONY: cpp parity docs check lint test build bench install dev uninstall clean

check:
> @for f in $$(find $(LIB) -name '*.sh') bin/proj install.sh tests/*.sh; do bash -n "$$f" || exit 1; done; echo "sintaxe ok"

lint:
> @command -v shellcheck >/dev/null || { echo "shellcheck não instalado (pkg install shellcheck)"; exit 0; }
> shellcheck -x -s bash -S warning $$(find $(LIB) -name '*.sh') bin/proj install.sh

test: check
> @bash tests/stubs.sh && bash tests/smoke.sh

build: dist/proj.sh
dist/proj.sh: $(shell find $(LIB) -name '*.sh')
> @mkdir -p dist
> @{ echo '#!/usr/bin/env bash'; echo '# proj - bundle gerado por "make build". Não edite; edite lib/proj/.'; \
>    for f in $(ORDER); do echo "# ---- $$f ----"; cat $(LIB)/$$f; echo; done; \
>    echo '[ -f "$$PROJ_FN" ] && . "$$PROJ_FN"'; \
>    echo 'if [[ $$- == *i* ]]; then complete -F _proj_complete proj 2>/dev/null; fi'; } > $@
> @bash -n $@ && echo "gerado: $@ ($$(wc -l < $@) linhas)"

bench: build
> @bash tests/bench.sh

install:
> ./install.sh
dev:
> ./install.sh --dev
uninstall:
> ./install.sh --uninstall

clean:
> rm -rf dist

docs:
> @bash tests/gen-interfaces.sh

cpp: bin/projd
bin/projd: src/main.cpp
> bash scripts/build-native.sh

parity: cpp
> @bash tests/parity.sh
