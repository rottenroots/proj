# completion.sh - autocompletar (Tab). Carregado só na 1ª vez que você aperta Tab.
# (antes: cut|sort|tr + 2x ls|tr a cada Tab; agora: bash puro)
_proj_complete() {
  local cur="${COMP_WORDS[COMP_CWORD]}" sub="${COMP_WORDS[1]}" names="" n p vend="" arch=""
  local -A s=()
  if [ -r "$PROJ_IDX" ]; then
    while IFS=$'\t' read -r n _; do
      [ -n "$n" ] && [ -z "${s[$n]:-}" ] && { s[$n]=1; names+="$n "; }
    done < "$PROJ_IDX"
  fi
  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=( $(compgen -W "$PROJ_CMDS $names" -- "$cur") )
    return
  fi
  case "$sub" in
    backup|b) if [ "$COMP_CWORD" -eq 2 ]; then COMPREPLY=( $(compgen -W "on off now ls restore $names" -- "$cur") )
              else COMPREPLY=( $(compgen -W "$names" -- "$cur") ); fi;;
    vendor|v) for p in "$PROJ_BASE/vendor"/*; do [ -e "$p" ] && vend+="${p##*/} "; done
              COMPREPLY=( $(compgen -W "add ls use rm $vend $names" -- "$cur") );;
    tag)      COMPREPLY=( $(compgen -W "add rm ls $names" -- "$cur") );;
    clean)    COMPREPLY=( $(compgen -W "on off dias min now status" -- "$cur") );;
    archive|a) for p in "$PROJ_BASE/archive"/*; do [ -e "$p" ] && arch+="${p##*/} "; done
              COMPREPLY=( $(compgen -W "ls restore $names $arch" -- "$cur") );;
    todo)     COMPREPLY=( $(compgen -W "add done rm ls -p" -- "$cur") );;
    config)   COMPREPLY=( $(compgen -W "PROJ_COLOR CLEAN_ON CLEAN_DIAS CLEAN_MIN IMUNE_TAG BKP_IV BKP_KEEP SIZE_WARN_MB FREE_WARN_MB NOTIFY HOOKS" -- "$cur") );;
    ls|l)     COMPREPLY=( $(compgen -W "-s -r -a -p -f -j -t $names" -- "$cur") );;
    *)        COMPREPLY=( $(compgen -W "$names" -- "$cur") );;
  esac
}
