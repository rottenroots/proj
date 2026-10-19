# cmd/ui.sh - proj ui: tela de configuração em tempo real (só teclado)
# shellcheck disable=SC2154
# K L T O S M SEL MSG UNDO_K UNDO_V são locais de proj_ui, vistos pelos helpers (escopo dinâmico do bash).

# @in (nada)  @effect tela alternativa; cada alteração grava em $PROJ_CFG e redesenha a prévia
# @ret 1 se não houver terminal
proj_ui() {
  [ -t 0 ] && [ -t 1 ] || { echo "proj ui precisa de um terminal." >&2; return 1; }
  proj_boot
  local -a K=(PROJ_COLOR CLEAN_ON CLEAN_DIAS CLEAN_MIN IMUNE_TAG BKP_IV BKP_KEEP SIZE_WARN_MB FREE_WARN_MB NOTIFY HOOKS PROJ_PICK BKP_ALL CMP_LINES PROJ_UI_KEY)
  local -A L=([PROJ_COLOR]="Cores" [CLEAN_ON]="Limpeza automática" [CLEAN_DIAS]="Limpar após (dias)"
    [CLEAN_MIN]="Manter por projeto" [IMUNE_TAG]="Tag de imunidade" [BKP_IV]="Backup: intervalo"
    [BKP_KEEP]="Backup: cópias" [SIZE_WARN_MB]="Alerta tamanho (MB)" [FREE_WARN_MB]="Alerta espaço (MB)"
    [NOTIFY]="Notificações" [HOOKS]="Hooks .proj-enter" [PROJ_UI_KEY]="Atalho desta tela" [PROJ_PICK]="Seletor no proj l" [BKP_ALL]="Backup em todos" [CMP_LINES]="Linhas na comparação")
  local -A T=([PROJ_COLOR]=enum [CLEAN_ON]=bool [CLEAN_DIAS]=num [CLEAN_MIN]=num [IMUNE_TAG]=txt
    [BKP_IV]=enum [BKP_KEEP]=num [SIZE_WARN_MB]=num [FREE_WARN_MB]=num [NOTIFY]=bool [HOOKS]=bool [PROJ_UI_KEY]=enum [PROJ_PICK]=bool [BKP_ALL]=bool [CMP_LINES]=num)
  local -A O=([PROJ_COLOR]="auto off" [BKP_IV]="30m 1h 6h 12h 1d 1w" [PROJ_UI_KEY]="off C-g C-o C-p")
  local -A S=([CLEAN_DIAS]=5 [CLEAN_MIN]=1 [BKP_KEEP]=1 [SIZE_WARN_MB]=100 [FREE_WARN_MB]=100 [CMP_LINES]=5)
  local -A M=([CLEAN_DIAS]=1 [CLEAN_MIN]=1 [BKP_KEEP]=1 [SIZE_WARN_MB]=50 [FREE_WARN_MB]=50 [CMP_LINES]=0)
  local SEL=0 MSG="" UNDO_K="" UNDO_V="" key rest k v n=${#K[@]}
  trap '_ui_leave; trap - INT; return 130' INT
  printf '\e[?1049h\e[?25l'
  while :; do
    _ui_draw
    IFS= read -rsn1 key || break
    if [[ $key == $'\e' ]]; then
      rest=""; read -rsn2 -t 0.05 rest
      case $rest in '[A'|OA) key=k;; '[B'|OB) key=j;; '[C'|OC) key=l;; '[D'|OD) key=h;; *) key=q;; esac
    fi
    MSG=""
    case $key in
      j) SEL=$(( (SEL + 1) % n ));;
      k) SEL=$(( (SEL - 1 + n) % n ));;
      l) _ui_change 1;;
      h) _ui_change -1;;
      ''|' ') _ui_change 0;;
      u) if [ -n "$UNDO_K" ]; then k=$UNDO_K; v=$UNDO_V; _ui_set "$k" "$v"; UNDO_K=""; fi;;
      q) break;;
    esac
  done
  _ui_leave; trap - INT
}

# @effect sai da tela alternativa e devolve o cursor
_ui_leave() { printf '\e[?25h\e[?1049l'; }

# @in chave valor  @effect grava via proj_config, recarrega config e cores, religa o atalho
_ui_set() {
  local k=$1 v=$2 old=${!1}
  [ "$v" = "$old" ] && return 0
  if proj_config "$k" "$v" >/dev/null 2>&1; then
    UNDO_K=$k; UNDO_V=$old
    proj_cfg_load; proj_colors
    [ "$k" = PROJ_UI_KEY ] && _ui_bind "$old"
  else
    MSG="valor inválido: $v"
  fi
  return 0
}

# @in tecla_antiga  @effect troca o bind do readline (só em shell interativo)
_ui_bind() {
  [[ $- == *i* ]] || return 0
  if [ -n "$1" ] && [ "$1" != off ]; then bind -r "\\$1" 2>/dev/null; fi
  if [ "$PROJ_UI_KEY" != off ]; then bind -x "\"\\${PROJ_UI_KEY}\": proj ui" 2>/dev/null; fi
  return 0
}

# @in -1|0|1  @effect altera a opção selecionada (bool alterna, enum cicla, num soma, 0 abre prompt)
_ui_change() {
  local k=${K[SEL]} cur d=$1 o i j n new
  cur=${!k}
  case ${T[$k]} in
    bool) if [ "$cur" = 1 ]; then new=0; else new=1; fi;;
    enum) read -ra o <<<"${O[$k]}"; n=${#o[@]}; i=0
          for (( j=0; j<n; j++ )); do [ "${o[j]}" = "$cur" ] && i=$j; done
          [ "$d" = 0 ] && d=1
          new=${o[(i + d + n) % n]};;
    num)  if [ "$d" = 0 ]; then _ui_ask; return 0; fi
          [[ $cur =~ ^[0-9]+$ ]] || cur=0
          new=$(( cur + d * S[$k] ))
          (( new < M[$k] )) && new=${M[$k]};;
    txt)  _ui_ask; return 0;;
  esac
  _ui_set "$k" "$new"
}

# @effect lê um valor digitado para a opção selecionada
_ui_ask() {
  local v k=${K[SEL]}
  printf '\e[?25h\n\e[K %s: ' "${L[$k]}"
  IFS= read -re v
  printf '\e[?25l'
  [ -n "$v" ] || return 0
  if [ "${T[$k]}" = num ]; then
    { [[ $v =~ ^[0-9]+$ ]] && (( 10#$v >= M[$k] )); } || { MSG="mínimo ${M[$k]}"; return 0; }
    v=$(( 10#$v ))
  fi
  _ui_set "$k" "$v"
}


# @effect amostra com as cores e limites atuais
_ui_preview() {
  local big
  big=$(proj_hum $(( (SIZE_WARN_MB + 1) * 1048576 )))
  proj_sec prévia
  printf ' %sdemo%s  %sv1.0  2d%s  %slab%s  120K\e[K\n' "$PC_B" "$PC_RST" "$PC_D" "$PC_RST" "$PC_C" "$PC_RST"
  printf ' %sbig%s   %sv2.1  9d%s  %s%s%s  acima do alerta\e[K\n' "$PC_B" "$PC_RST" "$PC_D" "$PC_RST" "$PC_R" "$big" "$PC_RST"
  printf ' %sok%s  %saviso%s  %serro%s\e[K\n' "$PC_G" "$PC_RST" "$PC_Y" "$PC_RST" "$PC_R" "$PC_RST"
}


# @effect redesenha a tela inteira (sem limpar antes: sem piscar)
_ui_draw() {
  local i k v mark lab
  printf '\e[H%s proj · configuração%s\e[K\n' "$PC_H" "$PC_RST"
  proj_rule
  for i in "${!K[@]}"; do
    k=${K[i]}; v=${!k}
    if [ "${T[$k]}" = bool ]; then
      if [ "$v" = 1 ]; then v="${PC_G}ligado${PC_RST}"; else v="${PC_D}desligado${PC_RST}"; fi
    fi
    proj_pad "${L[$k]}" 22; lab=$REPLY
    if (( i == SEL )); then
      printf '%s▸ %s%s%s %s\e[K\n' "$PC_H" "$lab" "$PC_RST" "" "$v"
    else
      printf '  %s %s\e[K\n' "$lab" "$v"
    fi
  done
  (( ${LINES:-24} >= 22 )) && _ui_preview
  printf '%s%s%s\e[K\n' "$PC_Y" "$MSG" "$PC_RST"
  printf '%s ↑↓ mover  ←→ alterar  ⏎ editar\e[K\n u desfazer  q sair%s\e[K\n\e[J' "$PC_D" "$PC_RST"
}
