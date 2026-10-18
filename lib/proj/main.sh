# main.sh - dispatcher. Único ponto que conhece a tabela comando -> função.
# Cada função proj_* é carregada sob demanda (lazy) no init.sh.
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
    add|adopt)       shift; proj_add "$@" ;;
    ui)              shift; proj_ui "$@" ;;
    pick|sel)        shift; proj_pick "$@" ;;
    cd)              shift; proj_cd "$@" ;;
    -)               proj_cd - ;;
    help|-h|--help|"") proj_help ;;
    *) if proj_resolve "$c" q; then proj_cd "$@"
       else echo "Comando ou projeto desconhecido: $c"; proj_help; return 1; fi ;;
  esac
}
