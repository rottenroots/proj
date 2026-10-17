#!/usr/bin/env bash
# tests/parity.sh - mesma entrada no shell e no projd; a saída tem que ser idêntica
ROOT=$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)
BIN="$ROOT/bin/projd"; [ -x "$BIN" ] || { echo "rode: make cpp"; exit 1; }
HOME=$(mktemp -d); export HOME; trap 'rm -rf "$HOME"' EXIT
. "$ROOT/lib/proj/init.sh"
mkdir -p "$PROJ_DIR"
printf 'a\t1.0\t/h/a\tdesc a\tlab\timune,x\t2026-01-01\na\t1.10\t/h/a2\t-\tlab\t-\t-\nb\t0.1\t/h/b/sub\t-\t-\t-\t\nc\t2.0\t/h/c\td\tx\t-\t2026\n' > "$PROJ_IDX"
printf 'a-1.0\t100\t3\t500\t900\t1\nb-0.1\t\t\t7\t\t\nzzz-1\t1\t1\t1\t1\t1\n' > "$PROJ_ST"
cp "$PROJ_ST" "$HOME/st.orig"
pass=0; fail=0
cmp_() { local d=$1 a b; shift
  a=$(PROJ_BIN=/nonexistent "$@" 2>&1; echo "rc=$?")
  b=$(PROJ_BIN="$BIN" "$@" 2>&1; echo "rc=$?")
  if [ "$a" = "$b" ]; then pass=$((pass+1)); echo "  ok   $d"
  else fail=$((fail+1)); echo "  FAIL $d"; diff <(echo "$a") <(echo "$b") | head -6; fi; }
here_at() { PWD=$1 proj_here; }
setcase() { cp "$HOME/st.orig" "$PROJ_ST"; "$@"; cat "$PROJ_ST"; }
cmp_ rows proj_rows
cmp_ find-a proj_find a
cmp_ find-a-1.10 proj_find a 1.10
cmp_ find-nada proj_find q
cmp_ here-a2 here_at /h/a2/x
cmp_ here-a here_at /h/a
cmp_ here-b here_at /h/b/sub
cmp_ here-nada here_at /h/ab
cmp_ st-get-a proj_st_get a-1.0
cmp_ st-get-b proj_st_get b-0.1
cmp_ st-get-nada proj_st_get nope
cmp_ st-set proj_st_set a-1.0 4:99 5:123
cmp_ st-set-novo setcase proj_st_set novo-1 2:5 6:1
cmp_ st-set-fill setcase proj_st_set b-0.1 3:2
cmp_ st-set-cmd setcase proj_st_set a-1.0 6:0
cp "$HOME/st.orig" "$PROJ_ST"; PROJ_BIN="$BIN" proj_touch a-1.0
n=$(PROJ_BIN="$BIN" proj_st_get a-1.0 | cut -f3)
if [ "$n" = 4 ]; then pass=$((pass+1)); echo "  ok   touch"; else fail=$((fail+1)); echo "  FAIL touch ($n)"; fi
echo; echo "$pass ok, $fail falha(s)"; [ "$fail" -eq 0 ]
