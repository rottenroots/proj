# nav/resolve.sh - achar projeto, resolver alvo, entrar (cd)
# Contrato de T_*: proj_resolve escreve T_N T_V T_D T_K T_L; proj_enter lê.

# @in nome [versao]  @out linhas do índice
proj_find() {
  if [ -x "$PROJ_BIN" ]; then "$PROJ_BIN" find "$1" "$2"; return; fi
  awk -F'\t' -v n="$1" -v v="$2" '$1==n && (v==""||$2==v)' "$PROJ_IDX" 2>/dev/null
}

# @g PWD  @out linha do projeto que contém o diretório atual (o mais profundo)
proj_here() {
  if [ -x "$PROJ_BIN" ]; then "$PROJ_BIN" here; return; fi
  awk -F'\t' -v p="$PWD" 'p==$3 || index(p,$3"/")==1 {
    if (length($3)>L) { L=length($3); m=$0 } } END { if (m!="") print m }' \
    "$PROJ_IDX" 2>/dev/null
}

# @in alvo [q]  alvo: nome | nome@versao | nome@? (pergunta) | . (aqui) | - (anterior)
# @out T_N T_V T_D T_K T_L   @ret 1 se não achou ($2=q -> silencioso)
# (antes: 6+ forks de grep/cut/sed/cat; agora só proj_find/proj_here)
proj_resolve() {
  local arg="${1:-.}" q="$2" pn pv m="" i v d
  local -a L=()
  case "$arg" in
    .) m=$(proj_here)
       if [ -z "$m" ]; then
         [ "$q" = q ] || echo "Você não está dentro de um projeto registrado." >&2
         return 1
       fi;;
    -) arg=
       [ -r "$PROJ_PREV" ] && read -r arg < "$PROJ_PREV"
       if [ -z "$arg" ]; then
         [ "$q" = q ] || echo "Sem projeto anterior." >&2
         return 1
       fi
       proj_resolve "$arg" "$q"; return;;
    *) pn="${arg%%@*}"; pv=""
       case "$arg" in *@*) pv="${arg#*@}";; esac
       if [ "$pv" = '?' ]; then
         m=$(proj_find "$pn")
         [ -n "$m" ] && mapfile -t L <<<"$m"
         if (( ${#L[@]} > 1 )); then
           echo "Versões de $pn:" >&2
           for i in "${!L[@]}"; do
             IFS=$'\t' read -r _ v d _ <<<"${L[i]}"
             echo "$((i+1))) v$v  $d" >&2
           done
           read -rp "Qual? " i
           m=
           [[ $i =~ ^[0-9]+$ ]] && (( i >= 1 )) && m="${L[i-1]:-}"
         fi
       else
         m=$(proj_find "$pn" "$pv")
         [ -n "$m" ] && mapfile -t L <<<"$m"
         if (( ${#L[@]} > 1 )); then
           m=$(printf '%s\n' "${L[@]}" | sort -t$'\t' -k2,2V | tail -1)
         fi
       fi;;
  esac
  if [ -z "$m" ]; then
    [ "$q" = q ] || echo "Projeto não encontrado: ${1:-aqui}" >&2
    return 1
  fi
  T_L="$m"
  IFS=$'\t' read -r T_N T_V T_D _ <<<"$m"
  T_K="$T_N-$T_V"
}

# @effect executa ./.proj-enter se HOOKS=1 e o arquivo é do usuário
proj_hook() { [ "${HOOKS:-1}" = 1 ] && [ -f ./.proj-enter ] && [ -O ./.proj-enter ] && . ./.proj-enter; return 0; }

# @in T_*  @effect cd, touch, atualiza ultimo/anterior, banner, hook, bg
# (precisa rodar no shell atual: faz cd e source)
proj_enter() {
  local cur="" tags
  cd "$T_D" || return 1
  proj_touch "$T_K"
  [ -r "$PROJ_LAST" ] && read -r cur < "$PROJ_LAST"
  if [ "$cur" != "$T_N@$T_V" ]; then
    [ -n "$cur" ] && echo "$cur" > "$PROJ_PREV"
    echo "$T_N@$T_V" > "$PROJ_LAST"
  fi
  IFS=$'\t' read -r _ _ _ _ _ tags _ <<<"$T_L"
  printf '%s▸%s %s%s%s %sv%s%s' "$PC_C" "$PC_RST" "$PC_B" "$T_N" "$PC_RST" "$PC_D" "$T_V" "$PC_RST"
  proj_is_imune "$tags" && printf ' 🔒'
  printf '\n'
  proj_hook
  ( proj_bg "$T_K" "$T_D" >/dev/null 2>&1 & )
}

# @in alvo [versao]  @effect resolve (com rescan se falhar) e entra
proj_cd() {
  proj_boot
  local arg="$1"
  [ -n "$2" ] && case "$arg" in *@*) ;; *) arg="$arg@$2";; esac
  if ! proj_resolve "$arg" q; then
    echo "Não achei '$1', reescaneando..."
    proj_scan >/dev/null
    proj_resolve "$arg" || return 1
  fi
  if [ ! -d "$T_D" ]; then   # registro velho: pasta foi apagada fora do proj
    echo "A pasta de '$T_N' não existe mais ($T_D). Limpando registro..."
    proj_scan full >/dev/null
    return 1
  fi
  proj_enter
}

# @in [alvo]  @out stdout caminho
proj_path() { proj_resolve "${1:-.}" || return 1; echo "$T_D"; }
