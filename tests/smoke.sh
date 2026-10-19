#!/usr/bin/env bash
# tests/smoke.sh - roda tudo num HOME temporário (não toca nos seus dados)
ROOT=$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)
export NO_COLOR=1
HOME=$(mktemp -d); export HOME
trap 'rm -rf "$HOME"' EXIT
. "$ROOT/lib/proj/init.sh"

pass=0; fail=0
_r() { if [ "$1" = 1 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s\n' "$2"; fi; }
ok() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then _r 1 "$d"; else _r 0 "$d"; fi; }
no() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then _r 0 "$d"; else _r 1 "$d"; fi; }
eq() { if [ "$2" = "$3" ]; then _r 1 "$1"; else _r 0 "$1 (esperado '$2', veio '$3')"; fi; }

echo "util"
eq "hum 1.4M"    "1.4M"  "$(proj_hum 1536000)"
eq "hum 900B"    "900B"  "$(proj_hum 900)"
eq "secs 2h"     7200    "$(proj_secs 2h)"
eq "fmt 1d"      1d      "$(proj_fmt_secs 86400)"
eq "bump 1.9"    1.10    "$(proj_bump 1.9)"
eq "tag_add"     a,b,c   "$(proj_tag_add a,b c)"
eq "tag_del"     a,c     "$(proj_tag_del a,b,c b)"
ok "nome válido"   proj_valid_name a-b.1
no "nome inválido" proj_valid_name "a b"

echo "fluxo"
proj_boot >/dev/null 2>&1
proj_new smoke -c lab -d teste >/dev/null 2>&1
eq "ls acha"  1 "$(proj_ls -t | grep -c '^smoke')"
proj_lock on smoke@1.0 >/dev/null
no "rm de imune recusa" proj_remove smoke@1.0 -y
proj_lock off smoke@1.0 >/dev/null
ok "rm" proj_remove smoke@1.0 -y
eq "ls vazio" 0 "$(proj_ls -t | grep -c '^smoke')"
ok "undo restaura" proj_undo 1

echo "add"
mkdir -p "$HOME/velho" && echo oi > "$HOME/velho/README.md"
proj_add "$HOME/velho" -c lab -d antigo >/dev/null 2>&1
eq "add registra" 1 "$(proj_ls -t | grep -c "^velho")"
eq "add preserva README" oi "$(tail -1 "$HOME/velho/README.md")"


echo "info"
proj_add "$HOME/velho" >/dev/null 2>&1
eq "info data modificada" 0 "$(proj_info velho 2>/dev/null | grep -c 1969)"

echo "tag"
proj_new tg-x -t a >/dev/null 2>&1
proj_tag add b,c >/dev/null 2>&1
eq "tag add multiplas" "a b c" "$(proj_tag ls)"
proj_tag rm b,c >/dev/null 2>&1
eq "tag rm multiplas" "a" "$(proj_tag ls)"

no "ui sem terminal recusa" proj_ui
no "pick sem terminal recusa" proj_pick
echo "backup global"
proj_new bg-x >/dev/null 2>&1
proj_resolve bg-x@1.0 q
BKP_ALL=1 proj_backup_auto "$T_K" "$T_D"
eq "backup global cria cópia" 1 "$(ls "$PROJ_BKP/bg-x-1.0"/*.tar.gz 2>/dev/null | wc -l)"
echo "backup e clean"
proj_new bk-t >/dev/null 2>&1
proj_resolve bk-t@1.0 q
mkdir -p "$PROJ_BKP/$T_K"
for s in 20200101 20200102 20200103; do : > "$PROJ_BKP/$T_K/$s-000000.tar.gz"; done
proj_backup_do "$T_K" "$T_D" 2 >/dev/null 2>&1
eq "backup mantém só 2" 2 "$(ls "$PROJ_BKP/$T_K"/*.tar.gz | wc -l)"
ok "backup é verificável" tar -tzf "$(ls -1 "$PROJ_BKP/$T_K"/*.tar.gz | tail -1)"
mkdir -p "$PROJ_BKP/removidos"
f1="$PROJ_BKP/removidos/old-1.0-20200101-000000.tar.gz"
f2="$PROJ_BKP/removidos/old-1.0-20200102-000000.tar.gz"
: > "$f1"; : > "$f2"; touch -d 2020-01-01 "$f1" "$f2"
NOTIFY=0 proj_clean_run quiet
no "clean apaga o antigo" test -e "$f1"
ok "clean preserva o mais novo" test -e "$f2"
echo "config"
proj_cfg_snapshot
eq "snapshot da config" 1 "$(ls "$PROJ_BKP/_config"/*.tar.gz 2>/dev/null | wc -l)"
echo "pick em lote"
proj_new pk-a >/dev/null 2>&1; proj_new pk-b >/dev/null 2>&1
_proj_src cmd/pick.sh
t_batch() {
  local filt="" msg="" n="" v=""
  local -A bk=() mk=() RI=()
  local -a R=() TG=()
  _pick_load
  mk["pk-a@1.0"]=1; mk["pk-b@1.0"]=1
  _pick_flag x
  proj_tag_in() { _pick_tag add; }
  _pick_targets
  for k in "${TG[@]}"; do proj_tag add lote,teste "$k" >/dev/null 2>&1; done
}
t_batch
eq "lote: imunidade em 2" 2 "$(proj_ls -t | grep -c 'imune')"
eq "lote: tags em 2" 2 "$(proj_ls -t | grep -c 'lote,teste')"
echo "comparação"
proj_new cmp-a >/dev/null 2>&1; proj_new cmp-b >/dev/null 2>&1
proj_resolve cmp-a@1.0 q
proj_backup_do "$T_K" "$T_D" 5 >/dev/null 2>&1
echo extra > "$T_D/novo.txt"; echo mais >> "$T_D/README.md"
r=$(proj_cmp cmp-a -b 2>&1)
eq "cmp: arquivo novo" 1 "$(grep -c '+ novo.txt' <<<"$r")"
eq "cmp: arquivo modificado" 1 "$(grep -c '~ README.md' <<<"$r")"
eq "cmp: limite -n" 1 "$(proj_cmp cmp-a -b -n 1 2>&1 | grep -c 'mais 1')"
eq "cmp: dois projetos" 1 "$(proj_cmp cmp-a cmp-b 2>&1 | grep -c '^categoria')"
echo; echo "$pass ok, $fail falha(s)"
[ "$fail" -eq 0 ]
