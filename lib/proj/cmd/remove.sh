# cmd/remove.sh - rm (lixeira com tar.gz) e undo
# proj rm <nome[@versao]|.> [-k] [-y] [-P]
#   padrão: cópia em $PROJ_BKP/removidos e apaga a pasta
#   -k: só desregistra | -y: sem confirmação | -P: exclusão real (sem cópia)
# @uses proj_resolve proj_is_imune proj_key_drop proj_regen proj_scan
proj_remove() {
  local yes="" keep="" purge="" alvo="" arg ans stamp bk tags d
  for arg in "$@"; do
    case "$arg" in -y) yes=1;; -k|--keep) keep=1;; -P|--purge) purge=1;; *) alvo="$arg";; esac
  done
  [ -z "$alvo" ] && { echo "uso: proj rm <nome[@versao]|.> [-k] [-y] [-P]"; return 1; }
  case "$alvo" in .|*@*) ;; *) alvo="$alvo@?";; esac   # com várias versões, sempre pergunta
  proj_resolve "$alvo" || return 1
  d="$T_D"
  IFS=$'\t' read -r _ _ _ _ _ tags _ <<<"$T_L"
  if proj_is_imune "$tags"; then
    echo "${PC_R}Projeto imune 🔒${PC_RST}: $T_K. Use: proj unlock $T_N@$T_V" >&2; return 1
  fi
  case "$d" in ""|/|"$HOME"|"$PROJ_BASE"|"$PROJ_BASE/projects"|"$PROJ_BASE/vendor"|"$PROJ_BASE/archive")
    echo "Recusado: caminho perigoso ($d)"; return 1;; esac
  case "$d" in "$PROJ_BASE"/?*) ;; *) echo "Recusado: fora de $PROJ_BASE ($d)"; return 1;; esac

  if [ ! -d "$d" ]; then
    echo "A pasta já não existe ($d). Só limpando o registro."
  elif [ -n "$keep" ]; then
    [ -n "$yes" ] || { read -rp "Desregistrar $T_K (a pasta fica)? [s/N] " ans
      case "$ans" in s|S|y|Y) ;; *) echo "Cancelado."; return 1;; esac; }
    sed -i '0,/^<!-- proj/s//<!-- (proj desativado)/' "$d/README.md" 2>/dev/null
  elif [ -n "$purge" ]; then
    echo "${PC_R}EXCLUSÃO REAL${PC_RST}: apaga $d e os backups periódicos. Sem cópia, sem volta."
    read -rp "Digite o nome do projeto ($T_N) pra confirmar: " ans
    [ "$ans" = "$T_N" ] || { echo "Cancelado."; return 1; }
    case "$PWD" in "$d"|"$d"/*) cd "${d%/*}" || cd "$HOME" || return;; esac
    rm -rf "$d" || return 1
    rm -rf "${PROJ_BKP:?}/$T_K"
    echo "Excluído definitivamente."
  else
    if [ -z "$yes" ]; then
      echo "Vai apagar: $d  (cópia de segurança fica em removidos/)"
      read -rp "Digite o nome do projeto ($T_N) pra confirmar: " ans
      [ "$ans" = "$T_N" ] || { echo "Cancelado."; return 1; }
    fi
    printf -v stamp '%(%Y%m%d-%H%M%S)T' -1
    bk="$PROJ_BKP/removidos/$T_K-$stamp.tar.gz"
    mkdir -p "$PROJ_BKP/removidos"
    tar -czf "$bk" -C "${d%/*}" "${d##*/}" 2>/dev/null ||
      { echo "Falhou o backup de segurança. Nada foi apagado."; rm -f "$bk"; return 1; }
    printf '%s\n%s\n' "$d" "$tags" > "${bk%.tar.gz}.meta"
    case "$PWD" in "$d"|"$d"/*) cd "${d%/*}" || cd "$HOME" || return;; esac
    rm -rf "$d" || return 1
    echo "Apagado. Cópia de segurança: $bk  (desfaça com: proj undo)"
  fi
  awk -F'\t' -v d="$d" '$3!=d' "$PROJ_IDX" > "$PROJ_IDX.tmp" && mv "$PROJ_IDX.tmp" "$PROJ_IDX"
  proj_key_drop "$T_K"
  proj_regen >/dev/null
  echo "Removido do registro: $T_K"
}

# @in [ls|N]  N = posição na lista (1 = mais recente)
# CORRIGIDO: o original usava "N) nome" como se fosse caminho; agora é array de caminhos.
proj_undo() {
  local f meta dir base i="${1:-1}" k
  local -a L=()
  mapfile -t L < <(ls -1t "$PROJ_BKP/removidos"/*.tar.gz 2>/dev/null | head -10)
  if [ "$1" = ls ]; then
    for k in "${!L[@]}"; do echo "$((k+1))) ${L[k]##*/}"; done
    return 0
  fi
  [[ $i =~ ^[0-9]+$ ]] && (( i >= 1 )) && f="${L[i-1]:-}"
  [ -z "$f" ] && { echo "Nada para restaurar (veja: proj undo ls)."; return 1; }
  meta="${f%.tar.gz}.meta"; dir=
  [ -r "$meta" ] && read -r dir < "$meta"
  if [ -z "$dir" ]; then
    base="${f##*/}"; base="${base%.tar.gz}"; base="${base%-[0-9]*-[0-9]*}"
    dir="$PROJ_BASE/projects/inbox/$base"
  fi
  [ -e "$dir" ] && { echo "Já existe: $dir"; return 1; }
  mkdir -p "${dir%/*}" && tar -xzf "$f" -C "${dir%/*}" || { echo "Falhou ao restaurar."; return 1; }
  proj_scan full >/dev/null
  echo "Restaurado em: $dir"
  cd "$dir" 2>/dev/null || return 0
}
