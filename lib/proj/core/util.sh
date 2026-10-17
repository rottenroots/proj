# core/util.sh - utilitários puros (sem estado). Sem forks quando possível.

# @in bytes  @out stdout "1.5M"   (puro bash; trunca em vez de arredondar)
proj_hum() {
  local b="${1:-0}" i=0 r=0 u=(B K M G T)
  b=${b%%.*}; [[ $b =~ ^[0-9]+$ ]] || b=0
  while (( b >= 1024 && i < 4 )); do r=$(( b % 1024 )); b=$(( b / 1024 )); i=$(( i + 1 )); done
  if (( i == 0 )); then printf '%d%s' "$b" B
  else printf '%d.%d%s' "$b" $(( r * 10 / 1024 )) "${u[i]}"; fi
}

# @in epoch  @out stdout "3d" | agora | nunca   (sem fork de date)
proj_ago() {
  local t="${1:-0}" s now
  [ "$t" -gt 0 ] 2>/dev/null || { echo nunca; return; }
  printf -v now '%(%s)T' -1
  s=$(( now - t ))
  if   (( s < 60 ));      then echo agora
  elif (( s < 3600 ));    then echo "$((s/60))m"
  elif (( s < 86400 ));   then echo "$((s/3600))h"
  elif (( s < 2592000 )); then echo "$((s/86400))d"
  else echo "$((s/2592000))mes"; fi
}

# @in epoch  @out stdout dd/mm/aaaa HH:MM | "-"   (printf %()T, sem fork)
proj_fdate() {
  if [ "${1:-0}" -gt 0 ] 2>/dev/null; then printf '%(%d/%m/%Y %H:%M)T\n' "${1%.*}"
  else echo "-"; fi
}

# @in chave valor  @g PC_D PC_RST
proj_kv() { printf '%s%-11s%s %s\n' "$PC_D" "$1" "$PC_RST" "$2"; }

# @in string  @out stdout escapada p/ JSON   (sem fork)
proj_jesc() { local s="${1//\\/}"; printf '%s' "${s//\"/\\\"}"; }

# @in msg  @g NOTIFY
proj_notify() {
  [ "${NOTIFY:-1}" = 1 ] && command -v termux-notification >/dev/null 2>&1 &&
    termux-notification --title "proj" --content "$1" >/dev/null 2>&1
  return 0
}

# @in [dir]  @out stdout MB livres
proj_free_mb() {
  df -Pk "${1:-$HOME}" 2>/dev/null | { read -r; read -r _ _ _ a _; echo $(( ${a:-0} / 1024 )); }
}

# @in string  @ret 0 se nome/versão válido ([A-Za-z0-9_][A-Za-z0-9._-]*)
proj_valid_name() { [[ "$1" =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*$ ]]; }
# @in string  @ret 0 se categoria válida (a/b/c, cada parte como um nome)
proj_valid_cat()  { [[ "$1" =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*(/[A-Za-z0-9_][A-Za-z0-9._-]*)*$ ]]; }
# @in string  @ret 0 se vazia ou lista [A-Za-z0-9_.,-]+
proj_valid_tags() { [ -z "$1" ] || [[ "$1" =~ ^[A-Za-z0-9_.,-]+$ ]]; }

# @in versao  @out stdout "1.0 -> 1.1"  @ret 1 se último campo não é número
proj_bump() {
  awk -v v="$1" 'BEGIN{ n=split(v,p,"."); if (p[n] !~ /^[0-9]+$/) exit 1
    p[n]++; s=p[1]; for(i=2;i<=n;i++) s=s"."p[i]; print s }'
}

# @in nome cmd...  @ret 99 se ocupado. Trava via mkdir (atômico); expira em 60min
proj_lockrun() {
  local l="$PROJ_DIR/.lk-$1" r; shift
  if [ -d "$l" ] && [ -n "$(find "$l" -maxdepth 0 -mmin +60 2>/dev/null)" ]; then rmdir "$l" 2>/dev/null; fi
  mkdir "$l" 2>/dev/null || return 99
  "$@"; r=$?
  rmdir "$l" 2>/dev/null
  return $r
}

# @in arquivos... (passe um glob SEM aspas no padrão)  @out BK_F = lista do mais novo p/ o mais velho
# Os nomes têm AAAAMMDD-HHMMSS, então a ordem alfabética do glob = cronológica.
# Substitui `ls -1t | head/tail` (1-3 forks por chamada). @ret 1 se nada casou.
_proj_desc() {
  BK_F=(); local i
  [ -e "$1" ] || return 1
  for (( i=$#; i>0; i-- )); do BK_F+=("${!i}"); done
}

# @in [largura] [char]  @out linha horizontal (máx. 72 colunas)
proj_rule() {
  local w="${1:-${COLUMNS:-0}}" c="${2:-─}" l
  { [[ $w =~ ^[0-9]+$ ]] && (( w > 0 )); } || w=$(tput cols 2>/dev/null || echo 60)
  (( w > 72 )) && w=72
  printf -v l '%*s' "$w" ''
  printf '%s%s%s\n' "$PC_D" "${l// /$c}" "$PC_RST"
}

# @in titulo [largura]  @out régua com o título embutido: "── titulo ─────"
proj_sec() {
  local t="$1" w="${2:-${COLUMNS:-0}}" l n
  { [[ $w =~ ^[0-9]+$ ]] && (( w > 0 )); } || w=$(tput cols 2>/dev/null || echo 60)
  (( w > 72 )) && w=72
  n=$(( w - ${#t} - 4 )); (( n < 3 )) && n=3
  printf -v l '%*s' "$n" ''
  printf '%s── %s%s%s%s %s%s\n' "$PC_D" "$PC_RST" "$PC_H" "$t" "$PC_RST$PC_D" "${l// /─}" "$PC_RST"
}
