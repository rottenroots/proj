# store/state.sh - estado.tsv, backup.tsv, imunes.tsv
# estado: 1=chave 2=acesso 3=acessos 4=bytes 5=bytes_ts 6=fav

# @in chave  @out linha do estado
proj_st_get() { if [ -x "$PROJ_BIN" ]; then "$PROJ_BIN" st get "$1"; return; fi; awk -F'\t' -v k="$1" '$1==k' "$PROJ_ST" 2>/dev/null; }

# @in chave campo:valor...  @effect upsert da linha
proj_st_set() {
  if [ -x "$PROJ_BIN" ]; then "$PROJ_BIN" st set "$@"; return; fi
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

# @in chave  @effect acesso=agora, acessos+1   (sem fork de date/cut)
proj_touch() {
  if [ -x "$PROJ_BIN" ]; then "$PROJ_BIN" st touch "$1"; return; fi
  local row c now
  row=$(proj_st_get "$1")
  IFS=$'\t' read -r _ _ c _ <<<"$row"
  printf -v now '%(%s)T' -1
  proj_st_set "$1" "2:$now" "3:$(( ${c:-0} + 1 ))"
}

# @in chave  @effect remove de estado/backup/imunes
proj_key_drop() {
  local f tmp
  for f in "$PROJ_ST" "$BKP_CFG" "$PROJ_IMU"; do
    tmp=$(mktemp "$f.XXXXXX") || continue
    awk -F'\t' -v k="$1" '$1!=k' "$f" > "$tmp" && mv "$tmp" "$f" || rm -f "$tmp"
  done
}

# @in antiga nova  @effect renomeia chave nos 3 arquivos + pasta de backup
proj_key_rename() {
  local f tmp
  for f in "$PROJ_ST" "$BKP_CFG" "$PROJ_IMU"; do
    tmp=$(mktemp "$f.XXXXXX") || continue
    O="$1" N="$2" awk -F'\t' -v OFS='\t' '$1==ENVIRON["O"]{$1=ENVIRON["N"]} {print}' "$f" > "$tmp" &&
      mv "$tmp" "$f" || rm -f "$tmp"
  done
  if [ -d "$PROJ_BKP/$1" ] && [ ! -e "$PROJ_BKP/$2" ]; then mv "$PROJ_BKP/$1" "$PROJ_BKP/$2"; fi
  return 0
}

# @effect reconstrói imunes.tsv a partir das tags; mantém os cujo dir sumiu
# (antes: 1 awk por linha do imunes; agora: array associativo, 1 awk total)
proj_imune_sync() {
  local tmp k d; local -A seen=()
  tmp=$(mktemp) || return
  awk -F'\t' -v t="${IMUNE_TAG:-imune}" \
    'index(","$6",", ","t",") { print $1"-"$2"\t"$3 }' "$PROJ_IDX" > "$tmp"
  while IFS=$'\t' read -r k d; do [ -n "$k" ] && seen[$k]=1; done < "$tmp"
  while IFS=$'\t' read -r k d; do
    [ -z "$k" ] && continue
    [ -d "$d" ] && continue
    [ -n "${seen[$k]:-}" ] || printf '%s\t%s\n' "$k" "$d" >> "$tmp"
  done < "$PROJ_IMU"
  cat "$tmp" > "$PROJ_IMU"; rm -f "$tmp"
}

# @out stdout: n v d desc cat tags criado | acesso acessos bytes fav
proj_rows() {
  if [ -x "$PROJ_BIN" ]; then "$PROJ_BIN" rows "$@"; return; fi
  awk -F'\t' -v OFS='\t' '
    function z(x) { return (x=="" ? 0 : x) }
    FILENAME==ARGV[1] { st[$1]=z($2) OFS z($3) OFS z($4) OFS z($6); next }
    { k=$1"-"$2; if (!(k in st)) st[k]="0" OFS "0" OFS "0" OFS "0"
      c=$7; if (c=="") c="-"
      print $1,$2,$3,$4,$5,$6,c,st[k] }' "$PROJ_ST" "$PROJ_IDX" 2>/dev/null
}
