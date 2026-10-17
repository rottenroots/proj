# core/config.sh - caminhos, defaults, cores, boot
# globals escritos: PROJ_*, BKP_CFG, PC_*, e as opções de proj_cfg_load

PROJ_BASE="${PROJ_BASE:-$HOME/dev}"          # projects/, vendor/ e archive/
PROJ_DIR="${PROJ_DIR:-$HOME/.config/proj}"
PROJ_IDX="$PROJ_DIR/index.tsv"               # nome versao dir desc categoria tags criado
PROJ_ST="$PROJ_DIR/estado.tsv"               # chave acesso acessos bytes bytes_ts fav
PROJ_FN="$PROJ_DIR/atalhos.sh"
BKP_CFG="$PROJ_DIR/backup.tsv"               # chave segundos manter
PROJ_CFG="$PROJ_DIR/config"
PROJ_LAST="$PROJ_DIR/ultimo"
PROJ_PREV="$PROJ_DIR/anterior"
PROJ_IMU="$PROJ_DIR/imunes.tsv"              # chave dir (projetos imunes)
if [ -d "$HOME/storage/shared" ]; then
  PROJ_BKP="${PROJ_BKP:-$HOME/storage/shared/proj-backups}"
else
  PROJ_BKP="${PROJ_BKP:-$HOME/.proj-backups}"
fi
PROJ_CMDS="add ls l info i new n backup b vendor v scan s path p edit e open o recent r archive a grep g rm del remove mv rename lock unlock fav unfav note todo tag undo clean doctor stale export config organize cd help"

# @out defaults + sobrescreve com $PROJ_CFG
proj_cfg_load() {
  PROJ_COLOR=auto; CLEAN_ON=1; CLEAN_DIAS=30; CLEAN_MIN=1; IMUNE_TAG=imune
  BKP_IV=1d; BKP_KEEP=5; SIZE_WARN_MB=500; FREE_WARN_MB=300; NOTIFY=1; HOOKS=1
  [ -f "$PROJ_CFG" ] && . "$PROJ_CFG"
  return 0
}


# @effect cria $PROJ_DIR e os .tsv vazios
proj_init() {
  mkdir -p "$PROJ_DIR"
  local f
  for f in "$PROJ_IDX" "$PROJ_ST" "$BKP_CFG" "$PROJ_IMU"; do [ -e "$f" ] || : > "$f"; done
}

# @effect 1x por sessão: config, dirs, migração v4
proj_boot() {
  [ -n "${_PROJ_BOOTED:-}" ] && { proj_colors; return 0; }
  _PROJ_BOOTED=1
  proj_cfg_load
  proj_init
  if [ ! -e "$PROJ_DIR/.v4" ]; then
    touch "$PROJ_DIR/.v4"; rm -f "$PROJ_DIR/.stamp"
    echo "proj: migrando para v4 (reescaneando)..." >&2
    proj_scan full >/dev/null
  fi
  proj_colors
}

# D=secundário  H=título  G/R/Y=ok/erro/aviso  C=categoria  M=destaque

# @out PC_* (vazias se stdout não é tty). Paleta 256 cores. Chamado A CADA comando.
# D=secundário  H=título  G/R/Y=ok/erro/aviso  C=categoria  M=destaque
proj_colors() {
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${PROJ_COLOR:-auto}" != off ]; then
    PC_RST=$'\e[0m'; PC_B=$'\e[1m'
    PC_D=$'\e[38;5;245m'; PC_H=$'\e[1;38;5;111m'
    PC_G=$'\e[38;5;114m'; PC_R=$'\e[38;5;203m'; PC_Y=$'\e[38;5;179m'
    PC_C=$'\e[38;5;80m';  PC_M=$'\e[38;5;176m'
  else
    PC_RST=; PC_B=; PC_D=; PC_H=; PC_G=; PC_R=; PC_Y=; PC_C=; PC_M=
  fi
}
