#!/usr/bin/env bash
# proj v4.0 - uso: source ~/.proj.sh  (no .bashrc, de preferência por último)
PROJ_BASE="${PROJ_BASE:-$HOME/dev}"          # projects/, vendor/ e archive/ ficam aqui
PROJ_DIR="$HOME/.config/proj"
PROJ_IDX="$PROJ_DIR/index.tsv"               # nome versao dir desc categoria tags criado
PROJ_ST="$PROJ_DIR/estado.tsv"               # chave acesso acessos bytes bytes_ts fav
PROJ_FN="$PROJ_DIR/atalhos.sh"
BKP_CFG="$PROJ_DIR/backup.tsv"               # chave segundos manter
PROJ_CFG="$PROJ_DIR/config"
PROJ_LAST="$PROJ_DIR/ultimo"
PROJ_PREV="$PROJ_DIR/anterior"
PROJ_IMU="$PROJ_DIR/imunes.tsv"              # chave dir (registro dos projetos imunes)
if [ -d "$HOME/storage/shared" ]; then
  PROJ_BKP="${PROJ_BKP:-$HOME/storage/shared/proj-backups}"
else
  PROJ_BKP="${PROJ_BKP:-$HOME/.proj-backups}"
fi
PROJ_CMDS="ls l info i new n backup b vendor v scan s path p edit e open o recent r archive a grep g rm del remove mv rename lock unlock fav unfav note todo tag undo clean doctor stale export config organize cd help"

# ---------- base: config, cores, util ----------
proj_cfg_load() {
  PROJ_COLOR=auto; CLEAN_ON=1; CLEAN_DIAS=30; CLEAN_MIN=1; IMUNE_TAG=imune
  BKP_IV=1d; BKP_KEEP=5; SIZE_WARN_MB=500; FREE_WARN_MB=300; NOTIFY=1; HOOKS=1
  [ -f "$PROJ_CFG" ] && . "$PROJ_CFG"
}

proj_colors() {
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${PROJ_COLOR:-auto}" != off ]; then
    PC_RST=$'\e[0m'; PC_B=$'\e[1m'; PC_D=$'\e[90m'; PC_G=$'\e[32m'
    PC_R=$'\e[31m'; PC_Y=$'\e[33m'; PC_C=$'\e[36m'; PC_M=$'\e[35m'
  else
    PC_RST=; PC_B=; PC_D=; PC_G=; PC_R=; PC_Y=; PC_C=; PC_M=
  fi
}

proj_init() {
  mkdir -p "$PROJ_DIR"
  local f
  for f in "$PROJ_IDX" "$PROJ_ST" "$BKP_CFG" "$PROJ_IMU"; do [ -e "$f" ] || : > "$f"; done
}

proj_boot() {
  proj_cfg_load
  proj_init
  if [ ! -e "$PROJ_DIR/.v4" ]; then
    touch "$PROJ_DIR/.v4"; rm -f "$PROJ_DIR/.stamp"
    echo "proj: migrando para v4 (reescaneando)..." >&2
    proj_scan full >/dev/null
  fi
  proj_colors
}

proj_hum() {  # bytes -> 1.5M
  awk -v b="${1:-0}" 'BEGIN{ split("B K M G T",u," "); i=1; while(b>=1024&&i<5){b/=1024;i++}
    if(i==1) printf "%d%s",b,u[i]; else printf "%.1f%s",b,u[i] }'
}

proj_ago() {  # epoch -> 3d
  local t="${1:-0}" s
  [ "$t" -gt 0 ] 2>/dev/null || { echo nunca; return; }
  s=$(( $(date +%s) - t ))
  if   [ $s -lt 60 ];      then echo agora
  elif [ $s -lt 3600 ];    then echo "$((s/60))m"
  elif [ $s -lt 86400 ];   then echo "$((s/3600))h"
  elif [ $s -lt 2592000 ]; then echo "$((s/86400))d"
  else echo "$((s/2592000))mes"; fi
}

proj_fdate() { if [ "${1:-0}" -gt 0 ] 2>/dev/null; then date -d "@${1%.*}" '+%d/%m/%Y %H:%M'; else echo "-"; fi; }
proj_kv() { printf '%s%-11s%s %s\n' "$PC_D" "$1" "$PC_RST" "$2"; }
proj_jesc() { printf '%s' "$1" | tr -d '\\' | sed 's/"/\\"/g'; }
proj_notify() {
  [ "${NOTIFY:-1}" = 1 ] && command -v termux-notification >/dev/null 2>&1 &&
    termux-notification --title "proj" --content "$1" >/dev/null 2>&1
  return 0
}
proj_free_mb() { df -Pk "${1:-$HOME}" 2>/dev/null | awk 'NR==2{printf "%d",$4/1024}'; }
proj_valid_name() { [[ "$1" =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*$ ]]; }
proj_valid_cat()  { [[ "$1" =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*(/[A-Za-z0-9_][A-Za-z0-9._-]*)*$ ]]; }
proj_valid_tags() { [ -z "$1" ] || [[ "$1" =~ ^[A-Za-z0-9_.,-]+$ ]]; }
proj_is_imune()   { case ",$1," in *",${IMUNE_TAG:-imune},"*) return 0;; esac; return 1; }

proj_tag_add() {
  local IFS=,; local out="" t seen=0
  for t in $1; do [ "$t" = - ] && continue; [ "$t" = "$2" ] && seen=1; out="${out:+$out,}$t"; done
  [ $seen = 1 ] || out="${out:+$out,}$2"
  echo "$out"
}
proj_tag_del() {
  local IFS=,; local out="" t
  for t in $1; do [ "$t" = "$2" ] || [ "$t" = - ] || out="${out:+$out,}$t"; done
  echo "$out"
}

proj_bump() {  # 1.0 -> 1.1
  awk -v v="$1" 'BEGIN{ n=split(v,p,"."); if (p[n] !~ /^[0-9]+$/) exit 1
    p[n]++; s=p[1]; for(i=2;i<=n;i++) s=s"."p[i]; print s }'
}

proj_lockrun() {  # nome cmd... (trava portátil; 99 = ocupado)
  local l="$PROJ_DIR/.lk-$1" r; shift
  if [ -d "$l" ] && [ -n "$(find "$l" -maxdepth 0 -mmin +60 2>/dev/null)" ]; then rmdir "$l" 2>/dev/null; fi
  mkdir "$l" 2>/dev/null || return 99
  "$@"; r=$?
  rmdir "$l" 2>/dev/null
  return $r
}

# ---------- README / índice / estado ----------
proj_readme_set() {  # dir chave valor
  local f="$1/README.md" tmp
  [ -f "$f" ] || return 1
  tmp=$(mktemp) || return 1
  K="$2" V="$3" awk '
    BEGIN { k=ENVIRON["K"]; v=ENVIRON["V"] }
    /^<!-- proj/ && !done { h=1; print; next }
    h && /-->/ { if (!set) print k": "v; h=0; set=1; done=1; print; next }
    h && !set && $0 ~ "^"k"[ \t]*:" { print k": "v; set=1; next }
    { print }' "$f" > "$tmp" && cat "$tmp" > "$f"
  rm -f "$tmp"
}

proj_idx_set() {  # dir coluna valor
  local tmp; tmp=$(mktemp "$PROJ_IDX.XXXXXX") || return 1
  D="$1" C="$2" V="$3" awk -F'\t' -v OFS='\t' \
    '$3==ENVIRON["D"] { $(ENVIRON["C"]+0)=ENVIRON["V"] } { print }' "$PROJ_IDX" > "$tmp" &&
    mv "$tmp" "$PROJ_IDX" || rm -f "$tmp"
}

proj_st_get() { awk -F'\t' -v k="$1" '$1==k' "$PROJ_ST" 2>/dev/null; }

proj_st_set() {  # chave campo:valor ...   (2=acesso 3=acessos 4=bytes 5=bytes_ts 6=fav)
  local k="$1" tmp; shift
  tmp=$(mktemp "$PROJ_ST.XXXXXX") || return 1
  K="$k" P="$*" awk -F'\t' -v OFS='\t' '
    BEGIN { n=split(ENVIRON["P"], a, " "); k=ENVIRON["K"] }
    $1==k { f=1; $6=$6; for(i=2;i<=6;i++) if($i=="") $i=0
            for(i=1;i<=n;i++){ split(a[i],kv,":"); $(kv[1])=kv[2] } print; next }
    { print }
    END { if (!f) { $0=""; $1=k; $2=0; $3=0; $4=0; $5=0; $6=0
            for(i=1;i<=n;i++){ split(a[i],kv,":"); $(kv[1])=kv[2] } print } }
  ' "$PROJ_ST" > "$tmp" && mv "$tmp" "$PROJ_ST" || rm -f "$tmp"
}

proj_touch() {
  local row c; row=$(proj_st_get "$1"); c=$(echo "$row" | cut -f3)
  proj_st_set "$1" "2:$(date +%s)" "3:$(( ${c:-0} + 1 ))"
}

proj_key_drop() {  # remove chave de estado/backup/imunes
  local f tmp
  for f in "$PROJ_ST" "$BKP_CFG" "$PROJ_IMU"; do
    tmp=$(mktemp "$f.XXXXXX") || continue
    awk -F'\t' -v k="$1" '$1!=k' "$f" > "$tmp" && mv "$tmp" "$f" || rm -f "$tmp"
  done
}

proj_key_rename() {  # antiga nova
  local f tmp
  for f in "$PROJ_ST" "$BKP_CFG" "$PROJ_IMU"; do
    tmp=$(mktemp "$f.XXXXXX") || continue
    O="$1" N="$2" awk -F'\t' -v OFS='\t' '$1==ENVIRON["O"]{$1=ENVIRON["N"]} {print}' "$f" > "$tmp" &&
      mv "$tmp" "$f" || rm -f "$tmp"
  done
  [ -d "$PROJ_BKP/$1" ] && [ ! -e "$PROJ_BKP/$2" ] && mv "$PROJ_BKP/$1" "$PROJ_BKP/$2"
}

proj_imune_sync() {
  local tmp k d; tmp=$(mktemp) || return
  awk -F'\t' -v t="${IMUNE_TAG:-imune}" 'index(","$6",", ","t",") { print $1"-"$2"\t"$3 }' "$PROJ_IDX" > "$tmp"
  while IFS=$'\t' read -r k d; do   # mantém os que sumiram (o doctor avisa)
    [ -z "$k" ] && continue
    [ -d "$d" ] && continue
    awk -F'\t' -v k="$k" '$1==k{f=1} END{exit !f}' "$tmp" || printf '%s\t%s\n' "$k" "$d" >> "$tmp"
  done < "$PROJ_IMU"
  cat "$tmp" > "$PROJ_IMU"; rm -f "$tmp"
}

proj_rows() {  # n v d desc cat tags criado | acesso acessos bytes fav
  awk -F'\t' -v OFS='\t' '
    function z(x) { return (x=="" ? 0 : x) }
    FILENAME==ARGV[1] { st[$1]=z($2) OFS z($3) OFS z($4) OFS z($6); next }
    { k=$1"-"$2; if (!(k in st)) st[k]="0" OFS "0" OFS "0" OFS "0"
      c=$7; if (c=="") c="-"
      print $1,$2,$3,$4,$5,$6,c,st[k] }' "$PROJ_ST" "$PROJ_IDX" 2>/dev/null
}

# ---------- busca / navegação ----------
proj_find() {
  awk -F'\t' -v n="$1" -v v="$2" '$1==n && (v==""||$2==v)' "$PROJ_IDX" 2>/dev/null
}

proj_here() {  # projeto que contém o diretório atual
  awk -F'\t' -v p="$PWD" 'p==$3 || index(p,$3"/")==1 {
    if (length($3)>L) { L=length($3); m=$0 } } END { if (m!="") print m }' \
    "$PROJ_IDX" 2>/dev/null
}

# alvo: nome | nome@versao | nome@? (pergunta) | . (aqui) | - (anterior)
# define T_N T_V T_D T_K T_L.  $2=q -> silencioso
proj_resolve() {
  local arg="${1:-.}" pn pv m="" i
  case "$arg" in
    .) m=$(proj_here)
       [ -z "$m" ] && { [ "$2" = q ] || echo "Você não está dentro de um projeto registrado." >&2; return 1; };;
    -) arg=$(cat "$PROJ_PREV" 2>/dev/null)
       [ -z "$arg" ] && { [ "$2" = q ] || echo "Sem projeto anterior." >&2; return 1; }
       proj_resolve "$arg" "$2"; return;;
    *) pn="${arg%%@*}"; pv=""; case "$arg" in *@*) pv="${arg#*@}";; esac
       if [ "$pv" = '?' ]; then
         m=$(proj_find "$pn")
         if [ "$(printf '%s\n' "$m" | grep -c .)" -gt 1 ]; then
           echo "Versões de $pn:" >&2
           printf '%s\n' "$m" | awk -F'\t' '{print NR") v"$2"  "$3}' >&2
           read -rp "Qual? " i
           m=$(printf '%s\n' "$m" | sed -n "${i}p")
         fi
       else
         m=$(proj_find "$pn" "$pv")
         [ "$(printf '%s\n' "$m" | grep -c .)" -gt 1 ] &&
           m=$(printf '%s\n' "$m" | sort -t$'\t' -k2,2V | tail -1)
       fi;;
  esac
  [ -z "$m" ] && { [ "$2" = q ] || echo "Projeto não encontrado: ${1:-aqui}" >&2; return 1; }
  T_L="$m"; T_N=$(echo "$m" | cut -f1); T_V=$(echo "$m" | cut -f2); T_D=$(echo "$m" | cut -f3)
  T_K="$T_N-$T_V"
}

proj_hook() { [ "${HOOKS:-1}" = 1 ] && [ -f ./.proj-enter ] && [ -O ./.proj-enter ] && . ./.proj-enter; return 0; }

proj_enter() {  # usa T_*
  local cur tags
  cd "$T_D" || return 1
  proj_touch "$T_K"
  cur=$(cat "$PROJ_LAST" 2>/dev/null)
  if [ "$cur" != "$T_N@$T_V" ]; then
    [ -n "$cur" ] && echo "$cur" > "$PROJ_PREV"
    echo "$T_N@$T_V" > "$PROJ_LAST"
  fi
  tags=$(echo "$T_L" | cut -f6)
  printf '%s▸%s %s%s%s %sv%s%s' "$PC_C" "$PC_RST" "$PC_B" "$T_N" "$PC_RST" "$PC_D" "$T_V" "$PC_RST"
  proj_is_imune "$tags" && printf ' 🔒'
  printf '\n'
  proj_hook
  ( proj_bg "$T_K" "$T_D" >/dev/null 2>&1 & )
}

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

proj_path() { proj_resolve "${1:-.}" || return 1; echo "$T_D"; }

# ---------- parse / scan ----------
proj_parse() {
  xargs -d '\n' -r awk -F: '
    FNR==1 { h=0; delete a; d=FILENAME; sub(/\/[^\/]*$/,"",d) }
    /^<!-- proj/ { h=1; next }
    h && /-->/ { h=0
      if (a["nome"]!="") {
        if (a["versao"]=="") a["versao"]="0"
        if (a["descricao"]=="") a["descricao"]="-"
        if (a["categoria"]=="") a["categoria"]="-"
        if (a["tags"]=="") a["tags"]="-"
        if (a["criado"]=="") a["criado"]="-"
        print a["nome"]"\t"a["versao"]"\t"d"\t"a["descricao"]"\t"a["categoria"]"\t"a["tags"]"\t"a["criado"]
      }
      next }
    h { i=index($0,":"); if (i) { k=substr($0,1,i-1); v=substr($0,i+1)
        gsub(/^[ \t]+|[ \t]+$/,"",k); gsub(/^[ \t]+|[ \t]+$/,"",v); a[k]=v } }
  '
}

proj_readmes() {  # $1=raiz $2=profundidade [$3=stamp]
  local newer=()
  [ -n "$3" ] && newer=(-newer "$3")
  find "$1" -maxdepth "$2" \
    \( -name .git -o -name node_modules -o -name .cache -o -name .npm \
       -o -name .config -o -name .local -o -path "$PROJ_BASE/vendor" \
       -o -path "$PROJ_BASE/archive" \) -prune -o \
    -name README.md "${newer[@]}" -print0 2>/dev/null |
  xargs -0r grep -l '^<!-- proj' 2>/dev/null | proj_parse
}

# nome já ocupado? ($1=candidato $2=já usados nesta rodada $3=atalhos antigos do proj)
proj_taken() {
  case " $2 " in *" $1 "*) return 0;; esac
  case "$(type -t "$1")" in
    "") return 1;;
    function) case " $3 " in *" $1 "*) return 1;; esac; return 0;;
    *) return 0;;
  esac
}

proj_regen() {
  local n new o used="" old=""
  [ -f "$PROJ_FN" ] && old=$(sed -n 's/^\([^(]*\)().*/\1/p' "$PROJ_FN" | tr '\n' ' ')
  : > "$PROJ_FN"
  while read -r n; do
    [ -z "$n" ] && continue
    new=$(printf '%s' "$n" | tr -c 'A-Za-z0-9_-' '_')
    case "$new" in [0-9-]*) new="p$new";; esac
    while proj_taken "$new" "$used" "$old"; do new="${new}x"; done
    used="$used $new"
    printf '%s() { proj_cd %q "$@"; }\n' "$new" "$n" >> "$PROJ_FN"
    if [ "$new" != "$n" ]; then
      echo "aviso: '$n' foi registrado, mas possivelmente poderá ter conflito com um comando ou projeto existente. Atalho criado: '$new' (sufixo x pra evitar conflito). Modifique manualmente se preferir. Digite proj help pra mais informações."
    fi
  done < <(cut -f1 "$PROJ_IDX" 2>/dev/null | sort -u)
  source "$PROJ_FN"
  # atalhos de projetos que sumiram deixam de existir na sessão atual
  for o in $old; do grep -q "^$o()" "$PROJ_FN" || unset -f "$o"; done
  echo "$(wc -l < "$PROJ_IDX") projeto(s) registrado(s)."
}

proj_scan() {
  mkdir -p "$PROJ_DIR" "$PROJ_BASE/projects" "$PROJ_BASE/vendor"
  local stamp="$PROJ_DIR/.stamp" novo="$PROJ_DIR/.novo" inc="" tmp
  local n v d desc c t cr
  [ -f "$stamp" ] && [ -f "$PROJ_IDX" ] && [ "$1" != "full" ] && inc=1
  touch "$stamp.tmp"
  tmp=$(mktemp "$PROJ_IDX.XXXXXX")
  if [ -n "$inc" ]; then
    proj_readmes "$PROJ_BASE" "${PROJ_DEPTH:-6}" "$stamp" > "$novo"
    cut -f3 "$novo" > "$novo.dirs"
    while IFS=$'\t' read -r n v d desc c t cr; do
      [ -d "$d" ] || continue
      grep -Fxq -- "$d" "$novo.dirs" && continue
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$v" "$d" "$desc" "$c" "$t" "${cr:--}" >> "$tmp"
    done < "$PROJ_IDX"
    cat "$novo" >> "$tmp"
    rm -f "$novo" "$novo.dirs"
  else
    proj_readmes "$PROJ_BASE" "${PROJ_DEPTH:-6}" > "$tmp"
  fi
  mv "$tmp" "$PROJ_IDX"
  mv "$stamp.tmp" "$stamp"
  proj_regen
  proj_imune_sync
  ( proj_size_all >/dev/null 2>&1 & )
}

# ---------- tamanho ----------
proj_size_calc() { du -sb --exclude=node_modules --exclude=.cache "$1" 2>/dev/null | cut -f1; }

proj_size_refresh() {  # chave dir [force]
  local row ts now s
  now=$(date +%s)
  row=$(proj_st_get "$1"); ts=$(echo "$row" | cut -f5)
  [ "$3" != force ] && [ $(( now - ${ts:-0} )) -lt 3600 ] && return 0
  [ -d "$2" ] || return 0
  s=$(proj_size_calc "$2"); [ -z "$s" ] && return 0
  proj_st_set "$1" "4:$s" "5:$now"
}

proj_size_all() {
  local n v d x
  while IFS=$'\t' read -r n v d x; do proj_size_refresh "$n-$v" "$d" "$1"; done < "$PROJ_IDX"
}

# ---------- criar ----------
# proj new nome [versao] [-c cat/sub] [-t tags] [-d "desc"] [-b versao_base|.]
proj_new() {
  local nome="" ver="" categ="" tags="" desc="" base="" pos=0 d srcd="" bt bsel
  while [ $# -gt 0 ]; do
    case "$1" in
      -c|-t|-d|-b)
        [ $# -ge 2 ] || { echo "Faltou valor para $1" >&2; return 1; }
        case "$1" in -c) categ="$2";; -t) tags="$2";; -d) desc="$2";; -b) base="$2";; esac
        shift 2;;
      *) pos=$((pos+1)); if [ $pos = 1 ]; then nome="$1"; else ver="$1"; fi; shift;;
    esac
  done
  [ -z "$nome" ] && { echo 'uso: proj new nome [versao] [-c cat/sub] [-t tags] [-d "desc"] [-b versao_base|.]'; return 1; }
  proj_valid_name "$nome" || { echo "Nome inválido (use letras, números, . _ -)" >&2; return 1; }
  if [ -n "$base" ]; then
    bsel="$nome"; [ "$base" != . ] && bsel="$nome@$base"
    proj_resolve "$bsel" || return 1
    if [ -z "$ver" ]; then
      ver=$(proj_bump "$T_V") || { echo "Não consegui incrementar '$T_V'; informe a versão." >&2; return 1; }
    fi
    [ -z "$categ" ] && categ=$(echo "$T_L" | cut -f5)
    bt=$(echo "$T_L" | cut -f6)
    [ -z "$tags" ] && tags=$(proj_tag_del "$bt" "$IMUNE_TAG")   # cópia não herda imunidade
    [ -z "$desc" ] && { desc=$(echo "$T_L" | cut -f4); [ "$desc" = - ] && desc=""; }
    srcd="$T_D"
  fi
  ver="${ver:-1.0}"; categ="${categ:-inbox}"; [ "$categ" = - ] && categ=inbox
  proj_valid_name "$ver"   || { echo "Versão inválida: $ver" >&2; return 1; }
  proj_valid_cat "$categ"  || { echo "Categoria inválida: $categ (use letras, números, . _ - e / para subpastas)" >&2; return 1; }
  proj_valid_tags "$tags"  || { echo "Tags inválidas (use letras, números, . _ - separadas por vírgula)" >&2; return 1; }
  desc="${desc//$'\n'/ }"; desc="${desc//-->/->}"
  d="$PROJ_BASE/projects/$categ/$nome-$ver"
  [ -e "$d" ] && { echo "Já existe: $d"; return 1; }
  if [ -n "$srcd" ]; then
    mkdir -p "$d" && tar -C "$srcd" --exclude=node_modules --exclude=.cache -cf - . | tar -C "$d" -xf - ||
      { echo "Falha ao copiar de $srcd" >&2; return 1; }
    proj_readme_set "$d" nome "$nome"; proj_readme_set "$d" versao "$ver"
    proj_readme_set "$d" categoria "$categ"; proj_readme_set "$d" tags "$tags"
    proj_readme_set "$d" criado "$(date '+%Y-%m-%d %H:%M')"
    [ -n "$desc" ] && proj_readme_set "$d" descricao "$desc"
  else
    mkdir -p "$d"/{src,resources,docs,refs}
    printf '<!-- proj\nnome: %s\nversao: %s\ncategoria: %s\ntags: %s\ncriado: %s\ndescricao: %s\n-->\n\n# %s\n\n%s\n' \
      "$nome" "$ver" "$categ" "$tags" "$(date '+%Y-%m-%d %H:%M')" "$desc" "$nome" "$desc" > "$d/README.md"
  fi
  proj_scan | grep -F "'$nome'"   # mostra só o aviso de conflito, se houver
  proj_resolve "$nome@$ver" q && proj_enter
}

# ---------- remover ----------
# proj rm <nome[@versao]|.> [-k] [-y] [-P]
#   padrão: cópia de segurança em $PROJ_BKP/removidos e apaga a pasta (lixeira)
#   -k: só desregistra | -y: sem confirmação | -P: exclusão real (sem cópia)
proj_remove() {
  local yes="" keep="" purge="" alvo="" arg ans stamp bk tags d
  for arg in "$@"; do
    case "$arg" in -y) yes=1;; -k|--keep) keep=1;; -P|--purge) purge=1;; *) alvo="$arg";; esac
  done
  [ -z "$alvo" ] && { echo "uso: proj rm <nome[@versao]|.> [-k] [-y] [-P]"; return 1; }
  case "$alvo" in .|*@*) ;; *) alvo="$alvo@?";; esac   # com várias versões, sempre pergunta
  proj_resolve "$alvo" || return 1
  d="$T_D"; tags=$(echo "$T_L" | cut -f6)
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
    case "$PWD" in "$d"|"$d"/*) cd "$(dirname "$d")" || cd "$HOME";; esac
    rm -rf "$d" || return 1
    rm -rf "${PROJ_BKP:?}/$T_K"
    echo "Excluído definitivamente."
  else
    if [ -z "$yes" ]; then
      echo "Vai apagar: $d  (cópia de segurança fica em removidos/)"
      read -rp "Digite o nome do projeto ($T_N) pra confirmar: " ans
      [ "$ans" = "$T_N" ] || { echo "Cancelado."; return 1; }
    fi
    stamp=$(date +%Y%m%d-%H%M%S)
    bk="$PROJ_BKP/removidos/$T_K-$stamp.tar.gz"
    mkdir -p "$PROJ_BKP/removidos"
    tar -czf "$bk" -C "$(dirname "$d")" "$(basename "$d")" 2>/dev/null ||
      { echo "Falhou o backup de segurança. Nada foi apagado."; rm -f "$bk"; return 1; }
    printf '%s\n%s\n' "$d" "$tags" > "${bk%.tar.gz}.meta"
    case "$PWD" in "$d"|"$d"/*) cd "$(dirname "$d")" || cd "$HOME";; esac
    rm -rf "$d" || return 1
    echo "Apagado. Cópia de segurança: $bk  (desfaça com: proj undo)"
  fi
  awk -F'\t' -v d="$d" '$3!=d' "$PROJ_IDX" > "$PROJ_IDX.tmp" && mv "$PROJ_IDX.tmp" "$PROJ_IDX"
  proj_key_drop "$T_K"
  proj_regen >/dev/null
  echo "Removido do registro: $T_K"
}

proj_undo() {
  local f meta dir lst i="${1:-1}" base
  if [ "$1" = ls ]; then
    ls -1t "$PROJ_BKP/removidos"/*.tar.gz 2>/dev/null | head -10 | awk '{n=split($0,p,"/"); print NR") "p[n]}'
    return 0
  fi
  lst=$(ls -1t "$PROJ_BKP/removidos"/*.tar.gz 2>/dev/null | head -10 | awk '{n=split($0,p,"/"); print NR") "p[n]}'
  f=$(printf '%s\n' "$lst" | sed -n "${i}p")
  [ -z "$f" ] && { echo "Nada para restaurar (veja: proj undo ls)."; return 1; }
  meta="${f%.tar.gz}.meta"; dir=$(sed -n 1p "$meta" 2>/dev/null)
  if [ -z "$dir" ]; then
    base=$(basename "$f" .tar.gz); base="${base%-[0-9]*-[0-9]*}"
    dir="$PROJ_BASE/projects/inbox/$base"
  fi
  [ -e "$dir" ] && { echo "Já existe: $dir"; return 1; }
  mkdir -p "$(dirname "$dir")" && tar -xzf "$f" -C "$(dirname "$dir")" || { echo "Falhou ao restaurar."; return 1; }
  proj_scan full >/dev/null
  echo "Restaurado em: $dir"
  cd "$dir" 2>/dev/null
}

# ---------- imunidade / favoritos / tags ----------
proj_lock() {  # on|off alvo
  proj_resolve "${2:-.}" || return 1
  local tags new
  tags=$(echo "$T_L" | cut -f6); [ "$tags" = - ] && tags=""
  if [ "$1" = on ]; then new=$(proj_tag_add "$tags" "$IMUNE_TAG"); else new=$(proj_tag_del "$tags" "$IMUNE_TAG"); fi
  proj_readme_set "$T_D" tags "$new" || { echo "README não encontrado em $T_D" >&2; return 1; }
  proj_idx_set "$T_D" 6 "${new:--}"
  proj_imune_sync
  if [ "$1" = on ]; then echo "🔒 $T_K agora é imune (rm, --purge e clean não tocam nele)."
  else echo "🔓 $T_K não é mais imune."; fi
}

proj_fav() {  # 1|0 alvo
  proj_resolve "${2:-.}" || return 1
  proj_st_set "$T_K" "6:$1"
  [ "$1" = 1 ] && echo "★ $T_K fixado no topo." || echo "$T_K desfixado."
}

proj_tag() {
  local op="$1" tg="$2" cur new
  case "$op" in
    ls) proj_resolve "${2:-.}" || return 1; echo "$T_L" | cut -f6 | tr ',' ' '; return;;
    add|rm) ;;
    *) echo "uso: proj tag add|rm <tag> [alvo]  |  proj tag ls [alvo]"; return 1;;
  esac
  [[ "$tg" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo "Tag inválida." >&2; return 1; }
  [ "$tg" = "$IMUNE_TAG" ] && { echo "Use proj lock/unlock para a tag '$IMUNE_TAG'." >&2; return 1; }
  proj_resolve "${3:-.}" || return 1
  cur=$(echo "$T_L" | cut -f6); [ "$cur" = - ] && cur=""
  if [ "$op" = add ]; then new=$(proj_tag_add "$cur" "$tg"); else new=$(proj_tag_del "$cur" "$tg"); fi
  proj_readme_set "$T_D" tags "$new" && proj_idx_set "$T_D" 6 "${new:--}" && echo "tags: ${new:-(nenhuma)}"
}

# ---------- mover / renomear ----------
# proj mv <alvo> [-n nome] [-v versao] [-c categoria]
proj_mv() {
  local alvo="" nn="" nv="" nc="" oc wasin=0 dest oldk newk od
  while [ $# -gt 0 ]; do
    case "$1" in
      -n|-v|-c) [ $# -ge 2 ] || { echo "Faltou valor para $1" >&2; return 1; }
        case "$1" in -n) nn="$2";; -v) nv="$2";; -c) nc="$2";; esac; shift 2;;
      *) alvo="$1"; shift;;
    esac
  done
  [ -z "$nn$nv$nc" ] && { echo "uso: proj mv <alvo> [-n nome] [-v versao] [-c categoria]"; return 1; }
  case "${alvo:-.}" in .|*@*) ;; *) alvo="$alvo@?";; esac
  proj_resolve "${alvo:-.}" || return 1
  oc=$(echo "$T_L" | cut -f5); [ "$oc" = - ] && oc=inbox
  nn="${nn:-$T_N}"; nv="${nv:-$T_V}"; nc="${nc:-$oc}"
  proj_valid_name "$nn" || { echo "Nome inválido." >&2; return 1; }
  proj_valid_name "$nv" || { echo "Versão inválida." >&2; return 1; }
  proj_valid_cat "$nc"  || { echo "Categoria inválida." >&2; return 1; }
  dest="$PROJ_BASE/projects/$nc/$nn-$nv"; od="$T_D"; oldk="$T_K"; newk="$nn-$nv"
  [ "$dest" = "$od" ] && { echo "Nada a mudar."; return 0; }
  [ -e "$dest" ] && { echo "Já existe: $dest"; return 1; }
  case "$PWD" in "$od"|"$od"/*) wasin=1;; esac
  mkdir -p "$(dirname "$dest")" && mv "$od" "$dest" || return 1
  proj_readme_set "$dest" nome "$nn"; proj_readme_set "$dest" versao "$nv"; proj_readme_set "$dest" categoria "$nc"
  [ "$oldk" != "$newk" ] && proj_key_rename "$oldk" "$newk"
  proj_scan full >/dev/null
  [ $wasin = 1 ] && cd "$dest"
  echo "Movido: $od -> $dest"
}

# ---------- arquivar ----------
proj_archive() {
  local d dest cat
  case "$1" in
    ls) ls -1 "$PROJ_BASE/archive" 2>/dev/null; return;;
    restore|r)
      [ -z "$2" ] && { echo "uso: proj archive restore <nome-versao>   (veja: proj archive ls)"; return 1; }
      d="$PROJ_BASE/archive/$2"; [ -d "$d" ] || { echo "Não existe: $d"; return 1; }
      cat=$(sed -n 's/^categoria:[ \t]*//p' "$d/README.md" 2>/dev/null | head -1)
      [ -z "$cat" ] || [ "$cat" = - ] && cat=inbox
      proj_valid_cat "$cat" || cat=inbox
      dest="$PROJ_BASE/projects/$cat/$2"
      [ -e "$dest" ] && { echo "Já existe: $dest"; return 1; }
      mkdir -p "$(dirname "$dest")" && mv "$d" "$dest" && proj_scan full >/dev/null &&
        echo "Desarquivado: $dest"; return;;
  esac
  case "${1:-.}" in .|*@*) set -- "${1:-.}";; *) set -- "$1@?";; esac
  proj_resolve "$1" || return 1
  dest="$PROJ_BASE/archive/$T_K"
  [ -e "$dest" ] && { echo "Já existe: $dest"; return 1; }
  case "$PWD" in "$T_D"|"$T_D"/*) cd "$(dirname "$T_D")" || cd "$HOME";; esac
  mkdir -p "$PROJ_BASE/archive" && mv "$T_D" "$dest" || return 1
  proj_scan full >/dev/null
  echo "Arquivado em: $dest  (volta com: proj archive restore $T_K)"
}
# ---------- vendor (diretórios copiados) ----------
# proj vendor add <projeto[@versao]|url|caminho> [nome] | ls | use <nome> | rm <nome>
proj_vendor() {
  local a="$1" src nome dest srcdir ans
  case "$a" in
    add)
      src="$2"
      [ -z "$src" ] && { echo "uso: proj vendor add <projeto[@versao]|url|caminho> [nome]"; return 1; }
      case "$src" in
        http*|git@*)   # URL: clona
          nome="${3:-$(basename "${src%.git}")}"; dest="$PROJ_BASE/vendor/$nome"
          proj_valid_name "$nome" || { echo "Nome inválido: $nome" >&2; return 1; }
          [ -e "$dest" ] && { echo "Já existe: $dest"; return 1; }
          mkdir -p "$PROJ_BASE/vendor"
          git clone --depth 1 "$src" "$dest" && echo "vendor/$nome pronto"
          return;;
      esac
      if proj_resolve "$src" q; then   # projeto registrado
        srcdir="$T_D"; nome="${3:-$T_N}"
      elif [ -d "$src" ]; then         # caminho
        srcdir="$src"; nome="${3:-$(basename "$src")}"
      else
        echo "Não achei projeto, caminho nem URL: $src"
        echo "Dica: proj ls  (lista os projetos registrados)"
        return 1
      fi
      proj_valid_name "$nome" || { echo "Nome inválido: $nome" >&2; return 1; }
      dest="$PROJ_BASE/vendor/$nome"
      [ -e "$dest" ] && { echo "Já existe: $dest"; return 1; }
      mkdir -p "$dest" &&
      tar -C "$srcdir" --exclude=node_modules --exclude=.cache -cf - . |
        tar -C "$dest" -xf - &&
      echo "vendor/$nome pronto (de $srcdir)";;
    ls|l) ls -1 "$PROJ_BASE/vendor";;
    use|u)
      proj_resolve . || return 1
      [ -d "$PROJ_BASE/vendor/$2" ] || { echo "vendor/$2 não existe"; return 1; }
      mkdir -p "$T_D/refs"; ln -sfn "$PROJ_BASE/vendor/$2" "$T_D/refs/$2"
      echo "refs/$2 -> vendor/$2";;
    rm|remove)
      [ -z "$2" ] && { echo "uso: proj vendor rm <nome>"; return 1; }
      dest="$PROJ_BASE/vendor/$2"
      [ -d "$dest" ] || { echo "vendor/$2 não existe"; return 1; }
      read -rp "Apagar vendor/$2? [s/N] " ans
      case "$ans" in s|S|y|Y) rm -rf "$dest" && echo "vendor/$2 removido";; *) echo "Cancelado.";; esac;;
    *) echo "proj vendor add <projeto[@versao]|url|caminho> [nome] | ls | use <nome> | rm <nome>";;
  esac
}

# ---------- organizar / migrar ----------
# proj organize [-n]   (-n = só mostra o que faria)
proj_organize() {
  local dry="" n v d desc c t cr c2 dest tmp
  [ "$1" = "-n" ] && dry=1
  tmp=$(mktemp)
  { proj_readmes "$HOME" 4; proj_readmes "$PROJ_BASE" "${PROJ_DEPTH:-6}"; } |
    sort -u -t$'\t' -k3,3 > "$tmp"
  while IFS=$'\t' read -r n v d desc c t cr; do
    if [ -z "$c" ] || [ "$c" = "-" ]; then
      c="inbox"
      if [ -z "$dry" ] && [ -r /dev/tty ]; then
        read -rp "Categoria de $n-$v [inbox]: " c2 </dev/tty
        c="${c2:-inbox}"
      fi
    fi
    proj_valid_cat "$c" || { echo "Categoria inválida para $n-$v: $c (pulado)"; continue; }
    dest="$PROJ_BASE/projects/$c/$n-$v"
    [ "$d" = "$dest" ] && continue
    if [ -e "$dest" ]; then echo "Pulado (destino existe): $dest"; continue; fi
    echo "$d -> $dest"
    [ -n "$dry" ] && continue
    mkdir -p "$(dirname "$dest")" && mv "$d" "$dest" || continue
    proj_readme_set "$dest" categoria "$c"
  done < "$tmp"
  rm -f "$tmp"
  [ -z "$dry" ] && proj_scan full
}

# ---------- backup ----------
proj_secs() {  # 30m 12h 1d 2w -> segundos
  local n="${1%[mhdw]}" u="${1##*[0-9]}"
  case "$n" in ''|*[!0-9]*) echo "Intervalo inválido: $1 (use 30m, 12h, 1d, 1w)" >&2; return 1;; esac
  case "$u" in
    m) echo $((n*60));; h) echo $((n*3600));; d) echo $((n*86400));; w) echo $((n*604800));;
    *) echo "Intervalo inválido: $1 (use 30m, 12h, 1d, 1w)" >&2; return 1;;
  esac
}

proj_fmt_secs() {  # segundos -> 30m 12h 1d 1w
  local s="$1"
  if   [ $((s % 604800)) -eq 0 ]; then echo "$((s/604800))w"
  elif [ $((s % 86400))  -eq 0 ]; then echo "$((s/86400))d"
  elif [ $((s % 3600))   -eq 0 ]; then echo "$((s/3600))h"
  else echo "$((s/60))m"; fi
}

proj_backup_do() {  # chave dir manter
  local k="$1" d="$2" keep="${3:-5}" out="$PROJ_BKP/$1" f r fr
  mkdir -p "$out"
  f="$out/$(date +%Y%m%d-%H%M%S).tar.gz"
  tar -czf "$f" --exclude=node_modules --exclude=.cache \
    -C "$(dirname "$d")" "$(basename "$d")" 2>/dev/null; r=$?
  if [ $r -le 1 ] && tar -tzf "$f" >/dev/null 2>&1; then   # verifica o arquivo gerado
    ls -1t "$out"/*.tar.gz 2>/dev/null | tail -n +$((keep+1)) | xargs -r rm -f
    fr=$(proj_free_mb "$PROJ_BKP"); [ -z "$fr" ] && fr=$(proj_free_mb "$HOME")
    [ "${fr:-999999}" -lt "${FREE_WARN_MB:-300}" ] && proj_notify "Pouco espaço livre: ${fr}MB (backup de $k)"
    return 0
  fi
  rm -f "$f"; proj_notify "Backup FALHOU: $k"
  return 1
}

proj_changed_since() {  # dir arquivo_ref
  [ -n "$(find "$1" \( -name node_modules -o -name .cache -o -name .git \) -prune -o \
    -type f -newer "$2" -print -quit 2>/dev/null)" ]
}

proj_backup_auto() {  # chave dir
  local k="$1" d="$2" cfg s keep lf last
  cfg=$(awk -F'\t' -v k="$k" '$1==k' "$BKP_CFG" 2>/dev/null); [ -z "$cfg" ] && return 0
  s=$(echo "$cfg" | cut -f2); keep=$(echo "$cfg" | cut -f3)
  lf=$(ls -1t "$PROJ_BKP/$k"/*.tar.gz 2>/dev/null | head -1)
  if [ -n "$lf" ]; then
    last=$(stat -c %Y "$lf")
    [ $(( $(date +%s) - last )) -ge "$s" ] || return 0
    proj_changed_since "$d" "$lf" || return 0      # nada mudou: pula
  fi
  proj_lockrun "bk-$k" proj_backup_do "$k" "$d" "$keep"
}

proj_free_check() {
  local st="$PROJ_DIR/.free" f
  [ -f "$st" ] && [ -z "$(find "$st" -mmin +1440 2>/dev/null)" ] && return 0
  f=$(proj_free_mb "$HOME")
  if [ "${f:-999999}" -lt "${FREE_WARN_MB:-300}" ]; then touch "$st"; proj_notify "Pouco espaço livre: ${f}MB"; fi
  return 0
}

proj_bg() { proj_backup_auto "$1" "$2"; proj_size_refresh "$1" "$2"; proj_clean_auto; proj_free_check; }

# proj backup [alvo] | on [alvo] [intervalo] [manter] | off [alvo] | now [alvo] | ls | restore [alvo] [-f]
proj_backup() {
  local a="${1:-now}" s iv keep k secs cnt last arg tgt force files i f dest stamp r sz
  [ $# -gt 0 ] && shift
  case "$a" in
    on)
      case "$1" in [0-9]*[mhdw]) set -- . "$@";; esac   # "proj b on 12h" vale pro projeto atual
      proj_resolve "$1" || return 1
      iv="${2:-$BKP_IV}"; keep="${3:-$BKP_KEEP}"
      s=$(proj_secs "$iv") || return 1
      case "$keep" in ''|*[!0-9]*|0) echo "Valor de 'manter' inválido: $keep" >&2; return 1;; esac
      awk -F'\t' -v k="$T_K" '$1!=k' "$BKP_CFG" > "$BKP_CFG.tmp"
      printf '%s\t%s\t%s\n' "$T_K" "$s" "$keep" >> "$BKP_CFG.tmp"
      mv "$BKP_CFG.tmp" "$BKP_CFG"
      echo "Backup ${PC_G}ativo${PC_RST}: $T_K a cada $iv, mantém $keep";;
    off)
      proj_resolve "$1" || return 1
      awk -F'\t' -v k="$T_K" '$1!=k' "$BKP_CFG" > "$BKP_CFG.tmp" 2>/dev/null
      mv "$BKP_CFG.tmp" "$BKP_CFG"; echo "Backup desativado: $T_K";;
    now|n)
      proj_resolve "$1" || return 1
      keep=$(awk -F'\t' -v k="$T_K" '$1==k {print $3}' "$BKP_CFG" 2>/dev/null)
      proj_lockrun "bk-$T_K" proj_backup_do "$T_K" "$T_D" "${keep:-$BKP_KEEP}"; r=$?
      case $r in
        0) f=$(ls -1t "$PROJ_BKP/$T_K"/*.tar.gz 2>/dev/null | head -1)
           sz=$(stat -c %s "$f" 2>/dev/null)
           echo "Backup feito: $T_K ($(proj_hum "$sz"), verificado)";;
        99) echo "Já há um backup de $T_K em andamento.";;
        *) echo "Backup FALHOU: $T_K"; return 1;;
      esac;;
    ls|l)
      [ -s "$BKP_CFG" ] || { echo "Nenhum backup ativado."; return; }
      printf '%s%-22s %-8s %-6s %-5s %s%s\n' "$PC_D" PROJETO INTERV MANTER QTD ULTIMO "$PC_RST"
      while IFS=$'\t' read -r k secs keep; do
        cnt=$(ls -1 "$PROJ_BKP/$k"/*.tar.gz 2>/dev/null | wc -l)
        last=$(ls -1t "$PROJ_BKP/$k"/*.tar.gz 2>/dev/null | head -1)
        if [ -n "$last" ]; then last=$(date -d "@$(stat -c %Y "$last")" '+%d/%m %H:%M'); else last="nunca"; fi
        printf '%s%-22s%s %-8s %-6s %-5s %s\n' "$PC_B" "$k" "$PC_RST" "$(proj_fmt_secs "$secs")" "$keep" "$cnt" "$last"
      done < "$BKP_CFG";;
    restore|r)
      force=""; tgt=""
      for arg in "$@"; do if [ "$arg" = "-f" ]; then force=1; else tgt="$arg"; fi; done
      proj_resolve "$tgt" || return 1
      files=$(ls -1t "$PROJ_BKP/$T_K"/*.tar.gz 2>/dev/null)
      [ -z "$files" ] && { echo "Sem backups de $T_K."; return 1; }
      echo "Backups de $T_K (mais novo primeiro):"
      echo "$files" | awk '{n=split($0,p,"/"); print NR") "p[n]}'
      read -rp "Qual? [1] " i; i="${i:-1}"
      f=$(echo "$files" | sed -n "${i}p")
      [ -z "$f" ] && { echo "Opção inválida."; return 1; }
      stamp=$(date +%Y%m%d-%H%M%S)
      if [ -n "$force" ]; then
        mkdir -p "$PROJ_BKP/pre-restore"
        tar -czf "$PROJ_BKP/pre-restore/$T_K-$stamp.tar.gz" \
          -C "$(dirname "$T_D")" "$(basename "$T_D")" || { echo "Falhou o backup de segurança."; return 1; }
        rm -rf "$T_D" && tar -xzf "$f" -C "$(dirname "$T_D")" &&
          echo "Restaurado em $T_D (versão anterior guardada em $PROJ_BKP/pre-restore)" &&
          cd "$T_D"
      else
        dest="$HOME/proj-restaurado/$T_K-$stamp"
        mkdir -p "$dest" && tar -xzf "$f" -C "$dest" &&
          echo "Restaurado em: $dest/$(basename "$T_D")  (use -f pra substituir o original)"
      fi;;
    *)
      if proj_resolve "$a" q; then proj_backup now "$a"
      else echo "proj b [alvo] | on [alvo] [intervalo] [manter] | off | ls | restore [alvo] [-f]"; fi;;
  esac
}

# ---------- limpeza automática ----------
proj_clean_del() {
  local f="$1" sz; sz=$(stat -c %s "$f" 2>/dev/null); sz=${sz:-0}
  _CL_N=$((_CL_N+1)); _CL_B=$((_CL_B+sz))
  [ -z "$_CL_Q" ] && printf '  %s %s (%s)\n' "$([ -n "$_CL_DRY" ] && echo apagaria || echo apagado)" "$(basename "$f")" "$(proj_hum "$sz")"
  [ -n "$_CL_DRY" ] || rm -f "$f" "${f%.tar.gz}.meta"
}

proj_clean_dir() {  # dir (cópias velhas; nunca as CLEAN_MIN mais novas de cada projeto)
  local dir="$1" f key meta tg pos S='[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]'
  [ -d "$dir" ] || return 0
  while IFS= read -r f; do
    key=$(basename "$f" .tar.gz); key="${key%-$S}"
    meta="${f%.tar.gz}.meta"
    if [ -f "$meta" ]; then tg=$(sed -n 2p "$meta"); proj_is_imune "$tg" && continue; fi
    pos=$(ls -1t "$dir"/"$key"-$S.tar.gz 2>/dev/null | grep -nFx -- "$f" | cut -d: -f1)
    [ "${pos:-0}" -le "${CLEAN_MIN:-1}" ] && continue
    proj_clean_del "$f"
  done < <(find "$dir" -maxdepth 1 -name '*.tar.gz' -mtime +"${CLEAN_DIAS:-30}" 2>/dev/null)
}

proj_clean_rotate() {  # backups periódicos acima do "manter"
  local k s keep f t
  while IFS=$'\t' read -r k s keep; do
    [ -z "$k" ] && continue
    t=$(awk -F'\t' -v k="$k" '$1"-"$2==k {print $6; exit}' "$PROJ_IDX")
    proj_is_imune "$t" && continue
    [ "${keep:-5}" -lt "${CLEAN_MIN:-1}" ] && keep="${CLEAN_MIN:-1}"
    while IFS= read -r f; do proj_clean_del "$f"; done < <(ls -1t "$PROJ_BKP/$k"/*.tar.gz 2>/dev/null | tail -n +$((keep+1)))
  done < "$BKP_CFG"
}

proj_clean_run() {
  local a
  _CL_N=0; _CL_B=0; _CL_DRY=""; _CL_Q=""
  for a in "$@"; do case "$a" in -n|dry) _CL_DRY=1;; quiet) _CL_Q=1;; esac; done
  proj_clean_dir "$PROJ_BKP/removidos"
  proj_clean_dir "$PROJ_BKP/pre-restore"
  proj_clean_rotate
  if [ -z "$_CL_Q" ]; then
    if [ "$_CL_N" -eq 0 ]; then echo "Nada para limpar."
    else echo "${_CL_DRY:+(simulação) }$_CL_N arquivo(s), $(proj_hum "$_CL_B")"; fi
  fi
  [ -z "$_CL_DRY" ] && [ "$_CL_N" -gt 0 ] && proj_notify "Limpeza: $_CL_N arquivo(s), $(proj_hum "$_CL_B") liberados"
  return 0
}

proj_clean_auto() {
  [ "${CLEAN_ON:-1}" = 1 ] || return 0
  local st="$PROJ_DIR/.clean"
  [ -f "$st" ] && [ -z "$(find "$st" -mmin +1440 2>/dev/null)" ] && return 0
  touch "$st"
  proj_lockrun clean proj_clean_run quiet
}

proj_config() {
  local k
  if [ -z "$1" ]; then
    for k in PROJ_COLOR CLEAN_ON CLEAN_DIAS CLEAN_MIN IMUNE_TAG BKP_IV BKP_KEEP SIZE_WARN_MB FREE_WARN_MB NOTIFY HOOKS; do
      printf '%s%-13s%s %s\n' "$PC_D" "$k" "$PC_RST" "${!k}"
    done; return
  fi
  case "$1" in PROJ_COLOR|CLEAN_ON|CLEAN_DIAS|CLEAN_MIN|IMUNE_TAG|BKP_IV|BKP_KEEP|SIZE_WARN_MB|FREE_WARN_MB|NOTIFY|HOOKS) ;;
    *) echo "Chave inválida: $1 (veja: proj config)" >&2; return 1;; esac
  [ -z "$2" ] && { echo "$1=${!1}"; return; }
  [[ "$2" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo "Valor inválido." >&2; return 1; }
  { grep -v "^$1=" "$PROJ_CFG" 2>/dev/null; echo "$1=$2"; } > "$PROJ_CFG.tmp" && mv "$PROJ_CFG.tmp" "$PROJ_CFG"
  echo "$1=$2"
}

proj_clean() {
  local a="${1:-status}"; [ $# -gt 0 ] && shift
  case "$a" in
    on)  proj_config CLEAN_ON 1 >/dev/null; echo "Limpeza automática ${PC_G}ligada${PC_RST}.";;
    off) proj_config CLEAN_ON 0 >/dev/null; echo "Limpeza automática ${PC_R}desligada${PC_RST}.";;
    dias) [[ "$1" =~ ^[0-9]+$ ]] || { echo "uso: proj clean dias <N>"; return 1; }
          proj_config CLEAN_DIAS "$1" >/dev/null; echo "Idade mínima: $1 dias.";;
    min)  [[ "$1" =~ ^[0-9]+$ ]] || { echo "uso: proj clean min <N>"; return 1; }
          proj_config CLEAN_MIN "$1" >/dev/null; echo "Mínimo mantido por projeto: $1.";;
    -n|dry) proj_clean_run -n;;
    now) proj_clean_run "$@";;
    status|*)
      printf 'Limpeza automática: %s | idade mínima: %s dias | mantém ao menos %s por projeto | imunidade: tag "%s"\n' \
        "$([ "${CLEAN_ON:-1}" = 1 ] && echo ligada || echo desligada)" "$CLEAN_DIAS" "$CLEAN_MIN" "$IMUNE_TAG"
      echo "uso: proj clean on|off | dias N | min N | now | -n (simula)";;
  esac
}

# ---------- listagens ----------
proj_ls() {
  local fmt="" sk=fav filt="" force="" showp="" W nw fx showc rest rows
  local n v d desc c t cr last cnt size fav mark col
  local total=0 np=0 miss=0
  while [ $# -gt 0 ]; do
    case "$1" in
      -j|--json) fmt=json;; -t|--tsv) fmt=tsv;;
      -s) sk=size;; -r) sk=recent;; -a) sk=alpha;;
      -p) showp=1;; -f) force=1;;
      *) filt="$1";;
    esac; shift
  done
  [ -n "$force" ] && { echo "Recalculando tamanhos..." >&2; proj_size_all force; }
  rows=$(proj_rows | awk -F'\t' -v f="$filt" 'f=="" || index($1,f) || index($5,f) || index($6,f)')
  if [ -z "$rows" ]; then
    [ "$fmt" = json ] && echo '[]'
    [ -z "$fmt" ] && echo "Nenhum projeto${filt:+ para '$filt'}."
    return 0
  fi
  case "$sk" in
    size)   rows=$(printf '%s\n' "$rows" | sort -t$'\t' -k10,10nr -k1,1);;
    recent) rows=$(printf '%s\n' "$rows" | sort -t$'\t' -k8,8nr -k1,1);;
    alpha)  rows=$(printf '%s\n' "$rows" | sort -t$'\t' -k1,1 -k2,2V);;
    *)      rows=$(printf '%s\n' "$rows" | sort -t$'\t' -k11,11nr -k1,1 -k2,2V);;
  esac
  case "$fmt" in
    tsv) printf 'nome\tversao\tdir\tdescricao\tcategoria\ttags\tcriado\tultimo_acesso\tacessos\tbytes\tfav\n'
         printf '%s\n' "$rows"; return;;
    json) printf '%s\n' "$rows" | awk -F'\t' '
      function e(s) { gsub(/\\/,"",s); gsub(/"/,"\\\"",s); return s }
      BEGIN { printf "[" }
      { printf "%s{\"nome\":\"%s\",\"versao\":\"%s\",\"dir\":\"%s\",\"descricao\":\"%s\",\"categoria\":\"%s\",\"tags\":\"%s\",\"criado\":\"%s\",\"ultimo_acesso\":%d,\"acessos\":%d,\"bytes\":%d,\"fav\":%d}", (NR>1?",":""), e($1),e($2),e($3),e($4),e($5),e($6),e($7),$8,$9,$10,$11 }
      END { print "]" }'; return;;
  esac
  W="${COLUMNS:-0}"; case "$W" in ''|*[!0-9]*) W=0;; esac
  [ "$W" -gt 0 ] || W=$(tput cols 2>/dev/null || echo 80)
  nw=$(printf '%s\n' "$rows" | awk -F'\t' '{ if (length($1)>m) m=length($1) } END{ print m+0 }')
  [ "$nw" -lt 6 ] && nw=6; [ "$nw" -gt 20 ] && nw=20
  fx=$((3+1+nw+1+7+1+7+1+6+1)); showc=0
  if [ "$W" -ge $((fx+13+12)) ]; then showc=1; fx=$((fx+13)); fi
  rest=$((W-fx)); [ "$rest" -lt 8 ] && rest=0
  printf '%s   %-*s %-7s ' "$PC_D" "$nw" NOME VERSAO
  [ $showc = 1 ] && printf '%-12s ' CATEGORIA
  printf '%7s %-6s ' TAM ULTIMO
  [ "$rest" -gt 0 ] && printf 'DESCRICAO'
  printf '%s\n' "$PC_RST"
  while IFS=$'\t' read -r n v d desc c t cr last cnt size fav; do
    np=$((np+1)); total=$((total+${size:-0})); [ "${size:-0}" -eq 0 ] && miss=$((miss+1))
    mark=" "; [ "$fav" = 1 ] && mark="★"
    if proj_is_imune "$t"; then mark="$mark🔒"; else mark="$mark  "; fi
    printf '%s ' "$mark"
    printf '%s%-*.*s%s ' "$PC_B" "$nw" "$nw" "$n" "$PC_RST"
    printf '%sv%-6.6s%s ' "$PC_D" "$v" "$PC_RST"
    [ $showc = 1 ] && printf '%s%-12.12s%s ' "$PC_C" "$c" "$PC_RST"
    col="$PC_RST"; [ "${size:-0}" -gt $(( SIZE_WARN_MB * 1048576 )) ] && col="$PC_R"
    if [ "${size:-0}" -gt 0 ]; then printf '%s%7s%s ' "$col" "$(proj_hum "$size")" "$PC_RST"; else printf '%7s ' "-"; fi
    printf '%s%-6s%s ' "$PC_D" "$(proj_ago "$last")" "$PC_RST"
    [ "$rest" -gt 0 ] && [ "$desc" != "-" ] && printf '%s' "${desc:0:rest}"
    printf '\n'
    [ -n "$showp" ] && printf '%s    %s%s\n' "$PC_D" "$d" "$PC_RST"
  done < <(printf '%s\n' "$rows")
  printf '%s%d projeto(s) · total %s%s\n' "$PC_D" "$np" "$(proj_hum "$total")" "$PC_RST"
  if [ "$miss" -gt 0 ]; then
    printf '%s(%d sem tamanho em cache; calculando em segundo plano)%s\n' "$PC_D" "$miss" "$PC_RST"
    ( proj_size_all >/dev/null 2>&1 & )
  fi
}

proj_recent() {
  local lim="${1:-10}" n v d desc c t cr last cnt size fav
  [[ "$lim" =~ ^[0-9]+$ ]] || lim=10
  while IFS=$'\t' read -r n v d desc c t cr last cnt size fav; do
    printf '%s%-6s%s %s%-18s%s %sv%-7s %sx%s\n' "$PC_D" "$(proj_ago "$last")" "$PC_RST" "$PC_B" "$n" "$PC_RST" "$PC_D" "$v" "$cnt" "$PC_RST"
  done < <(proj_rows | awk -F'\t' '$8>0' | sort -t$'\t' -k8,8nr | head -n "$lim")
}

proj_stale() {
  local days="${1:-30}" cut n v d desc c t cr last cnt size fav found=0
  [[ "$days" =~ ^[0-9]+$ ]] || days=30
  cut=$(( $(date +%s) - days*86400 ))
  echo "Sem acesso há mais de $days dias:"
  while IFS=$'\t' read -r n v d desc c t cr last cnt size fav; do
    found=1
    printf '  %s%-18s%s v%-7s %-6s %7s%s\n' "$PC_B" "$n" "$PC_RST" "$v" "$(proj_ago "$last")" "$([ "$size" -gt 0 ] && proj_hum "$size" || echo -)" "$(proj_is_imune "$t" && echo ' 🔒')"
  done < <(proj_rows | awk -F'\t' -v c="$cut" '$8<c' | sort -t$'\t' -k8,8n)
  [ $found = 0 ] && echo "  (nenhum)"
  echo "${PC_D}Dica: proj archive <nome> guarda sem apagar.${PC_RST}"
}

proj_grep() {
  local ic="" txt="" n v d x l
  for x in "$@"; do case "$x" in -i) ic="-i";; *) txt="$x";; esac; done
  [ -z "$txt" ] && { echo "uso: proj grep [-i] <texto>"; return 1; }
  while IFS=$'\t' read -r n v d x; do
    [ -d "$d" ] || continue
    ( cd "$d" && grep -rIn $ic --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.cache -e "$txt" . 2>/dev/null ) |
      while IFS= read -r l; do printf '%s%s%s/%s\n' "$PC_C" "$n" "$PC_RST" "${l#./}"; done
  done < "$PROJ_IDX" | head -n 200
}

# ---------- info ----------
proj_info() {
  local json="" arg="" x desc c t cr row last cnt fav d k n v
  local sz_t sz_f mod bk iv keep bcnt blast bstat vend gitb gitn free lock=0
  for x in "$@"; do case "$x" in -j|--json) json=1;; *) arg="$x";; esac; done
  proj_resolve "${arg:-.}" || return 1
  n="$T_N"; v="$T_V"; d="$T_D"; k="$T_K"
  IFS=$'\t' read -r _ _ _ desc c t cr <<< "$T_L"
  [ -d "$d" ] || { echo "A pasta não existe mais: $d" >&2; return 1; }
  proj_is_imune "$t" && lock=1
  row=$(proj_st_get "$k"); last=$(echo "$row" | cut -f2); cnt=$(echo "$row" | cut -f3); fav=$(echo "$row" | cut -f6)
  sz_t=$(du -sb "$d" 2>/dev/null | cut -f1); sz_f=$(proj_size_calc "$d")
  proj_st_set "$k" "4:${sz_f:-0}" "5:$(date +%s)"
  mod=$(find "$d" \( -name .git -o -name node_modules -o -name .cache \) -prune -o -type f -printf '%T@\n' 2>/dev/null | sort -n | tail -1)
  bk=$(awk -F'\t' -v k="$k" '$1==k' "$BKP_CFG")
  bcnt=$(ls -1 "$PROJ_BKP/$k"/*.tar.gz 2>/dev/null | wc -l)
  blast=$(ls -1t "$PROJ_BKP/$k"/*.tar.gz 2>/dev/null | head -1)
  [ -n "$blast" ] && blast=$(stat -c %Y "$blast") || blast=0
  vend=$(find "$d/refs" -maxdepth 1 -type l -printf '%f ' 2>/dev/null)
  if [ -d "$d/.git" ] && command -v git >/dev/null 2>&1; then
    gitb=$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null)
    gitn=$(git -C "$d" status --porcelain 2>/dev/null | wc -l)
  fi
  if [ -n "$json" ]; then
    printf '{"nome":"%s","versao":"%s","dir":"%s","descricao":"%s","categoria":"%s","tags":"%s","criado":"%s","ultimo_acesso":%d,"acessos":%d,"bytes":%d,"bytes_total":%d,"modificado":%d,"imune":%s,"fav":%s,"backup_ativo":%s,"backups":%d,"ultimo_backup":%d,"vendors":"%s","git_branch":"%s","git_alteracoes":%d}\n' \
      "$(proj_jesc "$n")" "$(proj_jesc "$v")" "$(proj_jesc "$d")" "$(proj_jesc "$desc")" "$(proj_jesc "$c")" "$(proj_jesc "$t")" "$(proj_jesc "$cr")" \
      "${last:-0}" "${cnt:-0}" "${sz_f:-0}" "${sz_t:-0}" "${mod%.*}" \
      "$([ $lock = 1 ] && echo true || echo false)" "$([ "$fav" = 1 ] && echo true || echo false)" \
      "$([ -n "$bk" ] && echo true || echo false)" "$bcnt" "$blast" "$(proj_jesc "${vend% }")" "$(proj_jesc "$gitb")" "${gitn:-0}"
    return
  fi
  if [ -n "$bk" ]; then
    iv=$(proj_fmt_secs "$(echo "$bk" | cut -f2)"); keep=$(echo "$bk" | cut -f3)
    bstat="${PC_G}ativo${PC_RST} (a cada $iv, mantém $keep) · $bcnt cópia(s) · última $(proj_fdate "$blast")"
  else
    bstat="${PC_R}off${PC_RST}$([ "$bcnt" -gt 0 ] && echo " · $bcnt cópia(s) antigas")"
  fi
  free=$(proj_free_mb "$d")
  printf '%s%s%s %sv%s%s' "$PC_B$PC_C" "$n" "$PC_RST" "$PC_D" "$v" "$PC_RST"
  [ $lock = 1 ] && printf ' 🔒 imune'; [ "$fav" = 1 ] && printf ' %s★%s' "$PC_Y" "$PC_RST"
  printf '\n'
  [ "$desc" != "-" ] && printf '%s%s%s\n' "$PC_D" "$desc" "$PC_RST"
  proj_kv caminho "$d"
  proj_kv categoria "$c"
  proj_kv tags "$(echo "$t" | tr ',' ' ')"
  proj_kv criado "${cr}"
  proj_kv modificado "$(proj_fdate "${mod%.*}")"
  proj_kv acesso "$(proj_fdate "${last:-0}") · ${cnt:-0}x"
  proj_kv tamanho "$(proj_hum "$sz_f") (sem node_modules/.cache) · total $(proj_hum "$sz_t")"
  proj_kv backup "$bstat"
  proj_kv vendor "${vend:--}"
  [ -n "$gitb" ] && proj_kv git "$gitb · $gitn alteração(ões) pendente(s)"
  proj_kv livre "$(proj_hum $(( ${free:-0} * 1048576 )))"
}

# ---------- notas / todo ----------
proj_note() {
  local tg="." txt
  [ "$1" = -p ] && { tg="$2"; shift 2; }
  proj_resolve "$tg" || return 1
  mkdir -p "$T_D/docs"
  txt="$*"
  if [ -z "$txt" ] || [ "$txt" = ls ]; then
    [ -f "$T_D/docs/notas.md" ] && cat "$T_D/docs/notas.md" || echo "Sem notas."
    return
  fi
  printf -- '- [%s] %s\n' "$(date '+%d/%m/%Y %H:%M')" "$txt" >> "$T_D/docs/notas.md"
  echo "Nota salva em $T_K."
}

proj_todo() {
  local tg="." op f
  [ "$1" = -p ] && { tg="$2"; shift 2; }
  proj_resolve "$tg" || return 1
  mkdir -p "$T_D/docs"; f="$T_D/docs/todo.md"; touch "$f"
  op="$1"
  case "$op" in
    ""|ls) [ -s "$f" ] || { echo "Sem tarefas."; return; }
           awk -v g="$PC_G" -v d="$PC_D" -v r="$PC_RST" '{ if ($0 ~ /^- \[x\]/) print d NR") "$0 r; else print NR") "$0 }' "$f";;
    done)  [[ "$2" =~ ^[0-9]+$ ]] || { echo "uso: proj todo done <N>"; return 1; }
           sed -i "${2}s/^- \[ \]/- [x]/" "$f"; echo "Feito: $2";;
    rm)    [[ "$2" =~ ^[0-9]+$ ]] || { echo "uso: proj todo rm <N>"; return 1; }
           sed -i "${2}d" "$f"; echo "Removida: $2";;
    add)   shift; printf -- '- [ ] %s\n' "$*" >> "$f"; echo "Adicionada.";;
    *)     printf -- '- [ ] %s\n' "$*" >> "$f"; echo "Adicionada.";;
  esac
}

# ---------- editar / abrir / exportar ----------
proj_edit() {
  proj_resolve "${1:-.}" || return 1
  "${EDITOR:-$(command -v nano || echo vi)}" "$T_D/${2:-README.md}"
  proj_scan >/dev/null
}

proj_open() {
  local f="README.md"; [ "$2" = -d ] && f=""
  proj_resolve "${1:-.}" || return 1
  if command -v termux-open >/dev/null 2>&1; then termux-open "$T_D/$f"
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$T_D/$f"
  else echo "Sem termux-open/xdg-open. Caminho: $T_D/$f"; fi
}

proj_export() {
  local out base n v d desc c t cr last cnt size fav bk
  base="$HOME"; [ -d "$HOME/storage/shared" ] && base="$HOME/storage/shared"
  if [ "$1" = -j ]; then
    out="${2:-$base/proj-relatorio-$(date +%Y%m%d).json}"
    proj_ls -j > "$out" && echo "Relatório: $out"; return
  fi
  out="${1:-$base/proj-relatorio-$(date +%Y%m%d).md}"
  {
    printf '# Relatório de projetos\n\nGerado em %s\n\n' "$(date '+%d/%m/%Y %H:%M')"
    printf '| Projeto | Versão | Categoria | Tags | Tamanho | Criado | Último acesso | Backup |\n|---|---|---|---|---|---|---|---|\n'
    while IFS=$'\t' read -r n v d desc c t cr last cnt size fav; do
      bk=off; awk -F'\t' -v k="$n-$v" '$1==k{f=1} END{exit !f}' "$BKP_CFG" && bk=on
      printf '| %s | %s | %s | %s | %s | %s | %s | %s |\n' "$n" "$v" "$c" "$t" "$(proj_hum "$size")" "$cr" "$(proj_ago "$last")" "$bk"
    done < <(proj_rows | sort -t$'\t' -k1,1 -k2,2V)
  } > "$out" && echo "Relatório: $out"
}

# ---------- doctor ----------
proj_doctor() {
  local fix="" issues=0 x n v d k o new dup
  [ "$1" = -f ] && fix=1
  _ok()  { printf '  %s✓%s %s\n' "$PC_G" "$PC_RST" "$1"; }
  _bad() { printf '  %s✗%s %s\n' "$PC_R" "$PC_RST" "$1"; issues=$((issues+1)); }
  echo "${PC_B}proj doctor${PC_RST}"
  for x in tar find du awk sed xargs; do command -v "$x" >/dev/null 2>&1 || _bad "falta o comando: $x"; done
  command -v git >/dev/null 2>&1 || echo "  ${PC_D}· git ausente (opcional: vendor via URL e info)${PC_RST}"
  command -v termux-notification >/dev/null 2>&1 || echo "  ${PC_D}· termux-api ausente (opcional: notificações)${PC_RST}"
  while IFS=$'\t' read -r n v d x; do
    [ -d "$d" ] || _bad "registro órfão: $n-$v ($d)"
  done < "$PROJ_IDX"
  while IFS=$'\t' read -r k d; do
    [ -z "$k" ] && continue
    [ -d "$d" ] || _bad "🔒 PROJETO IMUNE SUMIU: $k ($d). Restaure: proj undo ls / proj archive ls"
  done < "$PROJ_IMU"
  dup=$(cut -f1,2 "$PROJ_IDX" | sort | uniq -d)
  [ -n "$dup" ] && _bad "nome+versão duplicados: $(echo "$dup" | tr '\t\n' '@ ')"
  while IFS=' ' read -r new o; do
    [ -n "$new" ] && [ "$new" != "$o" ] && echo "  ${PC_Y}!${PC_RST} atalho '$new' aponta para '$o' (conflito de nome evitado)"
  done < <(sed -n 's/^\([^(]*\)() { proj_cd \([^ ]*\) "$@"; }$/\1 \2/p' "$PROJ_FN" 2>/dev/null)
  while IFS=$'\t' read -r k x x; do
    [ -z "$k" ] && continue
    awk -F'\t' -v k="$k" '$1"-"$2==k{f=1} END{exit !f}' "$PROJ_IDX" || _bad "backup.tsv sem projeto: $k"
  done < "$BKP_CFG"
  if [ -d "$PROJ_BKP" ]; then
    for d in "$PROJ_BKP"/*/; do
      k=$(basename "$d")
      case "$k" in removidos|pre-restore) continue;; esac
      awk -F'\t' -v k="$k" '$1"-"$2==k{f=1} END{exit !f}' "$PROJ_IDX" ||
        echo "  ${PC_Y}!${PC_RST} backups sem projeto registrado: $k"
    done
  fi
  x=$(proj_free_mb "$HOME")
  if [ "${x:-999999}" -lt "$FREE_WARN_MB" ]; then _bad "pouco espaço livre: ${x}MB"; else _ok "espaço livre: ${x}MB"; fi
  if [ -n "$fix" ]; then
    proj_scan full >/dev/null
    while IFS=$'\t' read -r k x x; do
      [ -z "$k" ] && continue
      awk -F'\t' -v k="$k" '$1"-"$2==k{f=1} END{exit !f}' "$PROJ_IDX" || proj_key_drop "$k"
    done < "$BKP_CFG"
    echo "  corrigido: reescaneado e backup.tsv limpo (registros imunes sumidos ficam até você restaurar)."
  fi
  [ $issues -eq 0 ] && _ok "tudo certo" || echo "  ${PC_D}$issues problema(s). Rode 'proj doctor -f' para corrigir o que for seguro.${PC_RST}"
  unset -f _ok _bad
}

# ---------- ajuda ----------
proj_help() {
  cat <<'AJUDA'
proj <nome[@versao]>           abre o projeto (atalho direto: <nome> [versao])
proj -                         volta ao projeto anterior   | proj nome@?  escolhe a versão
proj l  [filtro] [-s|-r|-a] [-p] [-f] [-j|-t]
                               lista (-s tamanho, -r recentes, -a A-Z, -p caminho,
                               -f recalcula tamanhos, -j json, -t tsv)
proj i  [alvo] [-j]            informações completas do projeto
proj n  nome [versao] [-c cat/sub] [-t tags] [-d "desc"] [-b versao_base|.]
                               novo projeto (-b copia de uma versão e incrementa)
proj p  <nome>                 imprime só o caminho   (ex: cd $(proj p x))
proj e  [alvo] [arquivo]       edita README (ou outro arquivo)   proj o  abre (termux-open)
proj r  [N]                    últimos acessados     proj stale [dias]  sem acesso
proj g  [-i] <texto>           busca em todos os projetos
proj mv <alvo> [-n nome] [-v versao] [-c categoria]
proj fav|unfav [alvo]          fixa no topo
proj lock|unlock [alvo]        imunidade 🔒 (tag "imune"): bloqueia rm, --purge e clean
proj tag add|rm <tag> [alvo]   proj tag ls [alvo]
proj note [-p alvo] [texto]    proj todo [-p alvo] [add txt | done N | rm N | ls]
proj a  [alvo]                 arquiva (sem apagar)  | a ls | a restore <nome-versao>
proj rm <alvo> [-k] [-y] [-P]  lixeira com cópia em removidos/ | -k só desregistra
                               | -P exclusão real (sem cópia, sempre confirma nome)
proj undo [ls|N]               restaura projeto apagado
proj clean [on|off|dias N|min N|now|-n]   limpeza de removidos/pre-restore/backups velhos
proj b  [alvo]                 backup agora   | b on [alvo] [30m|12h|1d|1w] [manter]
proj b  off|now [alvo] | ls | restore [alvo] [-f]
proj v  add <projeto[@versao]|url|caminho> [nome] | ls | use <nome> | rm <nome>
proj s  [full]                 reescaneia     proj organize [-n]
proj doctor [-f]               diagnóstico    proj export [-j] [arquivo]
proj config [chave [valor]]    configurações (cores, limites, intervalo padrão...)

Aliases: l i n p e o r a g b v s. O rm não tem apelido de uma letra (de propósito).
Se um projeto tiver o nome de um subcomando, abra com: proj cd <nome>.
Conflitos: se o nome do projeto bate com um comando, função ou outro projeto,
o atalho ganha sufixo x (say -> sayx). Nomes começando com número ganham
prefixo p (2048 -> p2048). Sempre dá pra abrir pelo nome original: proj <nome>.
Hook: um arquivo .proj-enter na raiz do projeto roda ao entrar (HOOKS=0 desliga).
Dados: ~/.config/proj (config, estado.tsv, atalhos.sh). Cores desligam com NO_COLOR=1.
AJUDA
}

# ---------- comando principal ----------
proj() {
  proj_boot
  local c="$1"
  case "$c" in
    ls|l)            shift; proj_ls "$@" ;;
    info|i)          shift; proj_info "$@" ;;
    new|n)           shift; proj_new "$@" ;;
    path|p)          shift; proj_path "$@" ;;
    edit|e)          shift; proj_edit "$@" ;;
    open|o)          shift; proj_open "$@" ;;
    recent|r)        shift; proj_recent "$@" ;;
    stale)           shift; proj_stale "$@" ;;
    grep|g)          shift; proj_grep "$@" ;;
    scan|s)          shift; proj_scan "$@" ;;
    backup|b)        shift; proj_backup "$@" ;;
    vendor|v)        shift; proj_vendor "$@" ;;
    archive|a)       shift; proj_archive "$@" ;;
    rm|remove|del)   shift; proj_remove "$@" ;;
    undo)            shift; proj_undo "$@" ;;
    mv|rename)       shift; proj_mv "$@" ;;
    lock)            shift; proj_lock on "$@" ;;
    unlock)          shift; proj_lock off "$@" ;;
    fav)             shift; proj_fav 1 "$@" ;;
    unfav)           shift; proj_fav 0 "$@" ;;
    tag)             shift; proj_tag "$@" ;;
    note)            shift; proj_note "$@" ;;
    todo)            shift; proj_todo "$@" ;;
    clean)           shift; proj_clean "$@" ;;
    doctor)          shift; proj_doctor "$@" ;;
    export)          shift; proj_export "$@" ;;
    config)          shift; proj_config "$@" ;;
    organize)        shift; proj_organize "$@" ;;
    cd)              shift; proj_cd "$@" ;;
    -)               proj_cd - ;;
    help|-h|--help|"") proj_help ;;
    *) if proj_resolve "$c" q; then proj_cd "$@"
       else echo "Comando ou projeto desconhecido: $c"; proj_help; return 1; fi ;;
  esac
}

# ---------- autocompletar (Tab) ----------
_proj_complete() {
  local cur="${COMP_WORDS[COMP_CWORD]}" sub="${COMP_WORDS[1]}" names
  names=$(cut -f1 "$PROJ_IDX" 2>/dev/null | sort -u | tr '\n' ' ')
  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=( $(compgen -W "$PROJ_CMDS $names" -- "$cur") )
    return
  fi
  case "$sub" in
    backup|b) if [ "$COMP_CWORD" -eq 2 ]; then COMPREPLY=( $(compgen -W "on off now ls restore $names" -- "$cur") )
              else COMPREPLY=( $(compgen -W "$names" -- "$cur") ); fi;;
    vendor|v) COMPREPLY=( $(compgen -W "add ls use rm $(ls -1 "$PROJ_BASE/vendor" 2>/dev/null | tr '\n' ' ') $names" -- "$cur") );;
    tag)      COMPREPLY=( $(compgen -W "add rm ls $names" -- "$cur") );;
    clean)    COMPREPLY=( $(compgen -W "on off dias min now status" -- "$cur") );;
    archive|a) COMPREPLY=( $(compgen -W "ls restore $names $(ls -1 "$PROJ_BASE/archive" 2>/dev/null | tr '\n' ' ')" -- "$cur") );;
    todo)     COMPREPLY=( $(compgen -W "add done rm ls -p" -- "$cur") );;
    config)   COMPREPLY=( $(compgen -W "PROJ_COLOR CLEAN_ON CLEAN_DIAS CLEAN_MIN IMUNE_TAG BKP_IV BKP_KEEP SIZE_WARN_MB FREE_WARN_MB NOTIFY HOOKS" -- "$cur") );;
    ls|l)     COMPREPLY=( $(compgen -W "-s -r -a -p -f -j -t $names" -- "$cur") );;
    *)        COMPREPLY=( $(compgen -W "$names" -- "$cur") );;
  esac
}

[ -f "$PROJ_FN" ] && source "$PROJ_FN"
if [ -n "$BASH_VERSION" ] && command -v complete >/dev/null 2>&1; then
  complete -F _proj_complete proj
fi
