# cmd/notes.sh - proj note [-p alvo] [texto|ls]  |  proj todo [-p alvo] [ls|add txt|done N|rm N|txt]
# Arquivos: $T_D/docs/notas.md e $T_D/docs/todo.md

# @in [-p alvo] [texto|ls]  @out stdout notas  @effect anexa em $T_D/docs/notas.md
proj_note() {
  local tg="." txt now
  [ "$1" = -p ] && { tg="$2"; shift 2; }
  proj_resolve "$tg" || return 1
  mkdir -p "$T_D/docs"
  txt="$*"
  if [ -z "$txt" ] || [ "$txt" = ls ]; then
    [ -f "$T_D/docs/notas.md" ] && cat "$T_D/docs/notas.md" || echo "Sem notas."
    return
  fi
  printf -v now '%(%d/%m/%Y %H:%M)T' -1
  printf -- '- [%s] %s\n' "$now" "$txt" >> "$T_D/docs/notas.md"
  echo "Nota salva em $T_K."
}

# @in [-p alvo] [ls|add txt|done N|rm N|txt]  @effect edita $T_D/docs/todo.md  @ret 1 se N inválido
proj_todo() {
  local tg="." op f
  [ "$1" = -p ] && { tg="$2"; shift 2; }
  proj_resolve "$tg" || return 1
  mkdir -p "$T_D/docs"; f="$T_D/docs/todo.md"; touch "$f"
  op="$1"
  case "$op" in
    ""|ls) [ -s "$f" ] || { echo "Sem tarefas."; return; }
           awk -v d="$PC_D" -v r="$PC_RST" '{ if ($0 ~ /^- \[x\]/) print d NR") "$0 r; else print NR") "$0 }' "$f";;
    done)  [[ "$2" =~ ^[0-9]+$ ]] || { echo "uso: proj todo done <N>"; return 1; }
           sed -i "${2}s/^- \[ \]/- [x]/" "$f"; echo "Feito: $2";;
    rm)    [[ "$2" =~ ^[0-9]+$ ]] || { echo "uso: proj todo rm <N>"; return 1; }
           sed -i "${2}d" "$f"; echo "Removida: $2";;
    add)   shift; printf -- '- [ ] %s\n' "$*" >> "$f"; echo "Adicionada.";;
    *)     printf -- '- [ ] %s\n' "$*" >> "$f"; echo "Adicionada.";;
  esac
}
