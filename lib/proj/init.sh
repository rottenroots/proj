#!/usr/bin/env bash
# proj - ponto de entrada. Uso (no .bashrc): source /caminho/lib/proj/init.sh
[ -n "${_PROJ_LOADED:-}" ] && return 0
_PROJ_LOADED=1

_p="${BASH_SOURCE[0]}"
[ -L "$_p" ] && _p=$(readlink -f "$_p")
case $_p in */*) ;; *) _p=./$_p ;; esac
PROJ_LIB="${_p%/*}"; unset _p

PROJ_BIN="${PROJ_LIB%/lib/proj}/bin/projd"
_proj_src() { . "$PROJ_LIB/$1"; }

# stubs: a 1ª chamada carrega o arquivo, que redefine a função de verdade
_proj_lazy() {  # arquivo fn...
  local f="$1" fn; shift
  for fn; do eval "$fn() { _proj_src '$f'; $fn \"\$@\"; }"; done
}

# eager (pequeno, usado por tudo)
_proj_src core/config.sh
_proj_src core/util.sh
_proj_src core/tags.sh

# lazy
_proj_lazy store/readme.sh proj_readme_set proj_idx_set
_proj_lazy store/state.sh  proj_st_get proj_st_set proj_touch proj_key_drop \
                           proj_key_rename proj_imune_sync proj_rows
_proj_lazy nav/resolve.sh  proj_find proj_here proj_resolve proj_hook proj_enter \
                           proj_cd proj_path
_proj_lazy store/scan.sh   proj_parse proj_readmes proj_taken proj_regen proj_scan
_proj_lazy store/size.sh   proj_size_calc proj_size_refresh proj_size_all

_proj_lazy cmd/new.sh      proj_new
_proj_lazy cmd/remove.sh   proj_remove proj_undo
_proj_lazy cmd/flags.sh    proj_lock proj_fav proj_tag
_proj_lazy cmd/mv.sh       proj_mv
_proj_lazy cmd/archive.sh  proj_archive
_proj_lazy cmd/vendor.sh   proj_vendor
_proj_lazy cmd/organize.sh proj_organize

_proj_lazy backup/backup.sh proj_secs proj_fmt_secs proj_backup_do proj_changed_since 
_proj_lazy backup/clean.sh  proj_clean_del proj_clean_dir proj_clean_rotate proj_clean_run 

_proj_lazy cmd/list.sh     proj_ls proj_recent proj_stale proj_grep
_proj_lazy cmd/info.sh     proj_info
_proj_lazy cmd/notes.sh    proj_note proj_todo
_proj_lazy cmd/misc.sh     proj_edit proj_open proj_export
_proj_lazy cmd/doctor.sh   proj_doctor

_proj_lazy cmd/help.sh     proj_help
_proj_lazy completion.sh   _proj_complete
_proj_src main.sh
if [[ $- == *i* ]] && command -v complete >/dev/null 2>&1; then
  complete -F _proj_complete proj
fi

_proj_lazy cmd/add.sh      proj_add
_proj_lazy cmd/ui.sh       proj_ui
_proj_lazy cmd/pick.sh     proj_pick
_proj_lazy backup/backup.sh proj_cfg_snapshot
# atalhos dos projetos (nome() { proj_cd nome; })
[ -f "$PROJ_FN" ] && . "$PROJ_FN"
_proj_lazy backup/backup.sh proj_backup_auto proj_free_check proj_bg proj_backup
_proj_lazy backup/clean.sh  proj_clean_auto proj_config proj_clean

# atalho do `proj ui`
if [[ $- == *i* ]] && [ -r "$PROJ_CFG" ]; then
  while IFS='=' read -r _a _b; do [ "$_a" = PROJ_UI_KEY ] && _k=$_b; done < "$PROJ_CFG"
  if [ -n "${_k:-}" ] && [ "$_k" != off ]; then bind -x "\"\\${_k}\": proj ui" 2>/dev/null; fi
  unset _a _b _k
fi
