# cmd/misc.sh - edit, open, export

# @in [alvo] [arquivo=README.md]  @effect abre no $EDITOR e rescaneia
proj_edit() {
  proj_resolve "${1:-.}" || return 1
  "${EDITOR:-$(command -v nano || echo vi)}" "$T_D/${2:-README.md}"
  proj_scan >/dev/null
}

# @in [alvo] [-d]  -d abre a pasta em vez do README
proj_open() {
  local f="README.md"; [ "$2" = -d ] && f=""
  proj_resolve "${1:-.}" || return 1
  if command -v termux-open >/dev/null 2>&1; then termux-open "$T_D/$f"
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$T_D/$f"
  else echo "Sem termux-open/xdg-open. Caminho: $T_D/$f"; fi
}

# proj export [arquivo.md] | -j [arquivo.json]
# (antes: 1 awk no backup.tsv por projeto; agora: array associativo)
# @in [arquivo.md] | -j [arquivo.json]  @out arquivo de relatório  @effect grava em ~/storage/shared ou $HOME
proj_export() {
  local out base d0 n v d desc c t cr last cnt size fav bk k
  local -A has=()
  base="$HOME"; [ -d "$HOME/storage/shared" ] && base="$HOME/storage/shared"
  printf -v d0 '%(%Y%m%d)T' -1
  if [ "$1" = -j ]; then
    out="${2:-$base/proj-relatorio-$d0.json}"
    proj_ls -j > "$out" && echo "Relatório: $out"; return
  fi
  out="${1:-$base/proj-relatorio-$d0.md}"
  while IFS=$'\t' read -r k _; do [ -n "$k" ] && has[$k]=1; done < "$BKP_CFG"
  {
    printf -v d0 '%(%d/%m/%Y %H:%M)T' -1
    printf '# Relatório de projetos\n\nGerado em %s\n\n' "$d0"
    printf '| Projeto | Versão | Categoria | Tags | Tamanho | Criado | Último acesso | Backup |\n|---|---|---|---|---|---|---|---|\n'
    while IFS=$'\t' read -r n v d desc c t cr last cnt size fav; do
      bk=off; [ -n "${has["$n-$v"]:-}" ] && bk=on
      printf '| %s | %s | %s | %s | %s | %s | %s | %s |\n' "$n" "$v" "$c" "$t" "$(proj_hum "$size")" "$cr" "$(proj_ago "$last")" "$bk"
    done < <(proj_rows | sort -t$'\t' -k1,1 -k2,2V)
  } > "$out" && echo "Relatório: $out"
}
