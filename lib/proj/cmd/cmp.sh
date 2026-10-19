# cmd/cmp.sh - comparações: proj i A B | proj i A -b[N] [-n LINHAS]
# Chamado pelo proj_info quando há dois alvos ou -b/-n.
# Limite: data+tamanho (resolução de minuto) pegam quase tudo, mas não um arquivo editado que manteve o mesmo tamanho no mesmo minuto.

# @in A B | A -b[N] [-n L]  -b = contra o backup mais recente (-bN = N-ésimo); -n = linhas (0 = todas; padrão $CMP_LINES)
# @out stdout comparação  @ret 1 em erro de uso ou alvo não achado
# @uses proj_resolve proj_sec proj_rule proj_pad proj_hum proj_fdate _proj_desc
proj_cmp() {
  local a="" b="" bk="" nth=1 lim="${CMP_LINES:-20}"
  while [ $# -gt 0 ]; do
    case "$1" in
      -b) bk=1;;
      -b[0-9]*) bk=1; nth=${1#-b};;
      -n) [ $# -ge 2 ] || { echo "-n precisa de um número" >&2; return 1; }; lim=$2; shift;;
      -n[0-9]*) lim=${1#-n};;
      -j|--json) echo "--json não vale para comparação." >&2; return 1;;
      -*) echo "opção desconhecida: $1" >&2; return 1;;
      *) if [ -z "$a" ]; then a=$1; elif [ -z "$b" ]; then b=$1
         else echo "uso: proj i <A> [B] | proj i <A> -b[N] [-n LINHAS]" >&2; return 1; fi;;
    esac
    shift
  done
  [[ $lim =~ ^[0-9]+$ ]] || { echo "linhas inválido: $lim" >&2; return 1; }
  { [[ $nth =~ ^[0-9]+$ ]] && (( nth >= 1 )); } || { echo "backup inválido: $nth" >&2; return 1; }
  if [ -n "$bk" ]; then
    [ -z "$b" ] || { echo "use -b com um só projeto (ou compare dois projetos, sem -b)." >&2; return 1; }
    _cmp_backup "${a:-.}" "$nth" "$lim"
  else
    { [ -n "$a" ] && [ -n "$b" ]; } || { echo "uso: proj i <A> <B>  |  proj i <A> -b" >&2; return 1; }
    _cmp_meta "$a" "$b"
  fi
}

# @in prefixo (CA|CB)  @effect preenche ${p}_lab/_cat/_tags/_cr/_tam/_tamb/_mod/_acc/_bk/_bn/_git (locais do chamador)
_cmp_gather() {
  local p=$1 d=$T_D cg tg cr row sz mod acc bn bkv=off k s git=""
  IFS=$'\t' read -r _ _ _ _ cg tg cr <<<"$T_L"
  row=$(proj_st_get "$T_K"); IFS=$'\t' read -r _ _ acc sz _ <<<"$row"
  [ "${sz:-0}" -gt 0 ] || sz=$(proj_size_calc "$d")
  mod=$(find "$d" \( -name .git -o -name node_modules -o -name .cache \) -prune -o -type f -printf '%T@\n' 2>/dev/null |
        awk '$1>m{m=$1} END{printf "%d", m}')
  bn=0; _proj_desc "$PROJ_BKP/$T_K"/*.tar.gz && bn=${#BK_F[@]}
  if [ "${BKP_ALL:-0}" = 1 ]; then bkv=on
  else while IFS=$'\t' read -r k s _; do [ "$k" = "$T_K" ] && { bkv=on; break; }; done < "$BKP_CFG"; fi
  if [ -d "$d/.git" ] && command -v git >/dev/null 2>&1; then git=$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null); fi
  printf -v "${p}_lab" '%s' "$T_N@$T_V"
  printf -v "${p}_cat" '%s' "$cg"
  printf -v "${p}_tags" '%s' "$tg"
  printf -v "${p}_cr" '%s' "$cr"
  printf -v "${p}_tamb" '%s' "${sz:-0}"
  printf -v "${p}_tam" '%s' "$(proj_hum "${sz:-0}")"
  printf -v "${p}_mod" '%s' "$(proj_fdate "$mod")"
  printf -v "${p}_acc" '%s' "${acc:-0}x"
  printf -v "${p}_bk" '%s' "$bkv"
  printf -v "${p}_bn" '%s' "$bn"
  printf -v "${p}_git" '%s' "$git"
}

# @in rotulo valorA valorB  @effect imprime a linha; amarelo se diferem
_cmp_row() {
  local a=${2:--} b=${3:--} la pa col="$PC_RST"
  proj_pad "$1" 11; la=$REPLY
  (( ${#a} > 21 )) && a="${a:0:20}…"
  (( ${#b} > 21 )) && b="${b:0:20}…"
  [ "$2" != "$3" ] && col="$PC_Y"
  proj_pad "$a" 22; pa=$REPLY
  printf '%s%s%s %s%s %s%s\n' "$PC_D" "$la" "$PC_RST" "$col" "$pa" "$b" "$PC_RST"
}

# @in A B  @out duas colunas com os metadados
_cmp_meta() {
  local CA_lab CA_cat CA_tags CA_cr CA_tam CA_tamb CA_mod CA_acc CA_bk CA_bn CA_git
  local CB_lab CB_cat CB_tags CB_cr CB_tam CB_tamb CB_mod CB_acc CB_bk CB_bn CB_git
  local delta sign pa pb
  proj_resolve "$1" || return 1; _cmp_gather CA
  proj_resolve "$2" || return 1; _cmp_gather CB
  proj_sec comparação
  proj_pad "" 11; pa=$REPLY
  proj_pad "${CA_lab:0:21}" 22; pb=$REPLY
  printf '%s%s %s%s %s%s\n' "$PC_H" "$pa" "$pb" "${CB_lab:0:21}" "$PC_RST" ""
  proj_rule
  _cmp_row categoria "$CA_cat" "$CB_cat"
  _cmp_row tags "$CA_tags" "$CB_tags"
  _cmp_row criado "$CA_cr" "$CB_cr"
  _cmp_row tamanho "$CA_tam" "$CB_tam"
  _cmp_row modificado "$CA_mod" "$CB_mod"
  _cmp_row acessos "$CA_acc" "$CB_acc"
  _cmp_row backup "$CA_bk" "$CB_bk"
  _cmp_row cópias "$CA_bn" "$CB_bn"
  _cmp_row git "$CA_git" "$CB_git"
  delta=$(( CB_tamb - CA_tamb )); sign="+"
  (( delta < 0 )) && { sign="-"; delta=$(( -delta )); }
  proj_pad delta 11
  printf '%s%s %s%s%s\n' "$PC_D" "$REPLY" "$sign$(proj_hum "$delta")" " (B em relação a A)" "$PC_RST"
  proj_rule
}

# @in alvo N linhas  @out arquivos novos/modificados/removidos desde o N-ésimo backup
_cmp_backup() {
  local nth=$2 lim=$3 f bt new=0 mod=0 del=0 shown=0 total k p cols sym line
  local -a L=()
  proj_resolve "$1" || return 1
  [ -d "$T_D" ] || { echo "A pasta não existe mais: $T_D" >&2; return 1; }
  _proj_desc "$PROJ_BKP/$T_K"/*.tar.gz || { echo "Sem backups de $T_K (crie com: proj b $T_K)." >&2; return 1; }
  f=${BK_F[nth-1]:-}
  [ -n "$f" ] || { echo "Só há ${#BK_F[@]} backup(s) de $T_K." >&2; return 1; }
  bt=$(stat -c %Y "$f")
  proj_sec comparação
  printf ' %s%s%s  vs  %s%s%s\n' "$PC_H" "$T_K" "$PC_RST" "$PC_D" "${f##*/}" "$PC_RST"
  printf ' %sbackup de %s · %s%s\n' "$PC_D" "$(proj_fdate "$bt")" "$(proj_hum "$(stat -c %s "$f")")" "$PC_RST"
  mapfile -t L < <(
    awk -F'\t' '
      FILENAME==ARGV[1] { bs[$3]=$1; bt[$3]=$2; next }
      { if (!($3 in bs)) print "N\t" $3
        else { if (bs[$3]!=$1 || bt[$3]!=$2) print "M\t" $3; seen[$3]=1 } }
      END { for (p in bs) if (!(p in seen)) print "D\t" p }' \
      <(tar -tzvf "$f" 2>/dev/null | awk '$1 ~ /^-/ { sz=$3; dt=$4" "$5; p=$0
            for (i=0;i<5;i++) sub(/^[^ ]+ +/,"",p); sub(/^[^\/]+\//,"",p); printf "%s\t%s\t%s\n", sz, dt, p }') \
      <(find "$T_D" \( -name node_modules -o -name .cache \) -prune -o -type f -printf '%s\t%TY-%Tm-%Td %TH:%TM\t%P\n' 2>/dev/null) |
    sort -t$'\t' -k2
  )
  total=${#L[@]}
  for line in "${L[@]}"; do
    case ${line%%$'\t'*} in N) new=$((new+1));; M) mod=$((mod+1));; D) del=$((del+1));; esac
  done
  if (( total == 0 )); then
    printf ' %ssem diferenças%s desde este backup.\n' "$PC_G" "$PC_RST"
    return 0
  fi
  printf ' %s+%d novos%s  %s~%d modificados%s  %s-%d removidos%s\n' \
    "$PC_G" "$new" "$PC_RST" "$PC_Y" "$mod" "$PC_RST" "$PC_R" "$del" "$PC_RST"
  proj_rule
  cols=${COLUMNS:-0}
  { [[ $cols =~ ^[0-9]+$ ]] && (( cols > 8 )); } || cols=$(tput cols 2>/dev/null || echo 60)
  for line in "${L[@]}"; do
    (( lim > 0 && shown >= lim )) && break
    k=${line%%$'\t'*}; p=${line#*$'\t'}
    (( ${#p} > cols - 4 )) && p="…${p: -$(( cols - 5 ))}"
    case $k in N) sym="${PC_G}+${PC_RST}";; M) sym="${PC_Y}~${PC_RST}";; *) sym="${PC_R}-${PC_RST}";; esac
    printf ' %s %s\n' "$sym" "$p"
    shown=$((shown+1))
  done
  (( total > shown )) && printf '%s … mais %d (use -n 0 para todos)%s\n' "$PC_D" $(( total - shown )) "$PC_RST"
  return 0
}
