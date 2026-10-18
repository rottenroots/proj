# Interfaces

Gerado por `tests/gen-interfaces.sh`. Não edite: altere os comentários em `lib/proj/`.
Tags: `@in` entradas, `@out` saída, `@g` globais, `@effect` efeitos colaterais, `@ret` retorno, `@uses` dependências.


## backup

### `backup/backup.sh`

- **`proj_secs`**
  - @in 30m|12h|1d|2w  @out stdout segundos  @ret 1 se inválido
- **`proj_fmt_secs`**
  - @in segundos  @out stdout 30m|12h|1d|1w
- **`proj_backup_do`**
  - @in chave dir [manter]  @effect cria tar.gz, verifica, poda acima de "manter", avisa pouco espaço
  - (antes: date + dirname + basename + ls|tail|xargs; agora só tar)
- **`proj_changed_since`**
  - @in dir arquivo_ref  @ret 0 se algum arquivo é mais novo que a referência
- **`proj_backup_auto`**
  - @in chave dir  @effect faz backup se o intervalo passou E algo mudou
  - (antes: awk + 2 cut + ls|head + date; agora: 1 read + glob + 1 stat)
- **`proj_free_check`**
  - @effect avisa (no máx. 1x/dia) se o espaço livre estiver baixo
- **`proj_bg`**
  - @in chave dir  @effect tarefas de fundo disparadas pelo proj_enter
- **`proj_backup`**
  - proj backup [alvo] | on [alvo] [intervalo] [manter] | off [alvo] | now [alvo] | ls | restore [alvo] [-f]
  - @in on|off|now|ls|restore|<alvo> [args]
  - @effect on/off: edita backup.tsv | now: tar.gz verificado | restore: extrai (-f substitui o original, com cópia em pre-restore)
  - @ret 0 ok, 1 erro
  - @uses proj_resolve proj_lockrun proj_backup_do proj_secs proj_fmt_secs _proj_desc

### `backup/clean.sh`

- **`proj_clean_del`**
  - @in arquivo  @effect apaga (ou só conta, se _CL_DRY) o .tar.gz e o .meta
- **`proj_clean_dir`**
  - @in dir  cópias com mais de CLEAN_DIAS dias; nunca as CLEAN_MIN mais novas de cada chave
  - (antes: basename + sed + ls|grep|cut por arquivo; agora: glob + loop em bash)
- **`proj_clean_rotate`**
  - backups periódicos acima do "manter"
  - (antes: 1 awk no índice por projeto; agora: tags carregadas 1x num array)
  - @g PROJ_IDX BKP_CFG CLEAN_MIN  @effect apaga backups periódicos acima do "manter" (pula imunes)
- **`proj_clean_run`**
  - @in [-n|dry] [quiet]
- **`proj_clean_auto`**
  - @effect no máx. 1x/dia, com trava
- **`proj_config`**
  - @in [chave [valor]]  @effect lista, lê ou grava em $PROJ_CFG
- **`proj_clean`**
  - proj clean [on|off|dias N|min N|now|-n]
  - @in on|off|dias N|min N|now|-n  @effect grava em $PROJ_CFG ou roda proj_clean_run  @ret 1 se N inválido

## cmd

### `cmd/add.sh`

- **`proj_add`**
  - cmd/add.sh - proj add [pasta] [nome] [versao] [-c cat] [-t tags] [-d "desc"]
  - @effect registra uma pasta existente (cria/completa o cabeçalho do README; não move nada)

### `cmd/archive.sh`

- **`proj_archive`**
  - cmd/archive.sh - proj archive [alvo] | ls | restore <nome-versao>
  - @effect move projeto entre projects/ e archive/, rescan

### `cmd/doctor.sh`

- **`proj_doctor`**
  - cmd/doctor.sh - proj doctor [-f]
  - Verifica dependências, registros órfãos, imunes sumidos, duplicados, atalhos, backups sem dono.
  - (antes: 1 awk no índice por backup/pasta e cut|sort|uniq; agora: um array com as chaves do índice)
  - @in [-f]  @out stdout diagnóstico  @effect -f: scan full + limpa backup.tsv órfão  @ret 0

### `cmd/flags.sh`

- **`proj_lock`**
  - @in on|off [alvo]
- **`proj_fav`**
  - @in 1|0 [alvo]
- **`proj_tag`**
  - @in add|rm <tag[,tag...]> [alvo]  |  ls [alvo]
  - @out ls: stdout tags separadas por espaço
  - @effect add/rm: edita tags no README e no index.tsv (aceita várias, separadas por vírgula; "imune" só via lock/unlock)
  - @ret 1 se tag inválida ou alvo não achado
  - @uses proj_resolve proj_tag_add proj_tag_del proj_readme_set proj_idx_set

### `cmd/help.sh`

- **`proj_help`** — _sem contrato_

### `cmd/info.sh`

- **`proj_info`**
  - cmd/info.sh - proj info [alvo] [-j]
  - @uses proj_resolve proj_st_get proj_st_set proj_size_calc proj_fmt_secs proj_fdate proj_hum proj_kv _proj_desc

### `cmd/list.sh`

- **`proj_ls`**
  - proj ls [filtro] [-j|-t] [-s|-r|-a] [-p] [-f]
  - @in [filtro] [-j|-t] [-s|-r|-a] [-p] [-f]  @out stdout tabela | json | tsv  @g PC_* SIZE_WARN_MB COLUMNS
  - @uses proj_rows proj_hum proj_ago proj_is_imune proj_size_all proj_rule
- **`proj_recent`**
  - @in [N=10]  últimos projetos acessados
- **`proj_stale`**
  - @in [dias=30]  projetos sem acesso há mais de N dias
- **`proj_grep`**
  - proj grep [-i] <texto>   (antes: 1 subshell com cd por projeto; agora grep direto no caminho)
  - @in [-i] texto  @out stdout "projeto/arquivo:linha:texto" (máx. 200)  @ret 1 sem texto

### `cmd/misc.sh`

- **`proj_edit`**
  - @in [alvo] [arquivo=README.md]  @effect abre no $EDITOR e rescaneia
- **`proj_open`**
  - @in [alvo] [-d]  -d abre a pasta em vez do README
- **`proj_export`**
  - proj export [arquivo.md] | -j [arquivo.json]
  - (antes: 1 awk no backup.tsv por projeto; agora: array associativo)
  - @in [arquivo.md] | -j [arquivo.json]  @out arquivo de relatório  @effect grava em ~/storage/shared ou $HOME

### `cmd/mv.sh`

- **`proj_mv`**
  - cmd/mv.sh - proj mv <alvo> [-n nome] [-v versao] [-c categoria]
  - @effect move a pasta, atualiza README, renomeia chave de estado/backup, rescan
  - @uses proj_resolve proj_valid_* proj_readme_set proj_key_rename proj_scan

### `cmd/new.sh`

- **`proj_new`**
  - cmd/new.sh - proj new nome [versao] [-c cat/sub] [-t tags] [-d "desc"] [-b versao_base|.]
  - @effect cria pasta + README com cabeçalho, registra e entra (cd)
  - @uses proj_resolve proj_bump proj_valid_* proj_tag_del proj_readme_set proj_scan proj_enter

### `cmd/notes.sh`

- **`proj_note`**
  - @in [-p alvo] [texto|ls]  @out stdout notas  @effect anexa em $T_D/docs/notas.md
- **`proj_todo`**
  - @in [-p alvo] [ls|add txt|done N|rm N|txt]  @effect edita $T_D/docs/todo.md  @ret 1 se N inválido

### `cmd/organize.sh`

- **`proj_organize`**
  - cmd/organize.sh - proj organize [-n]   (-n = só mostra o que faria)
  - @effect acha READMEs proj em $HOME (prof. 4) e $PROJ_BASE e move p/ projects/<cat>/<nome-versao>
  - @uses proj_readmes proj_valid_cat proj_readme_set proj_scan

### `cmd/pick.sh`

- **`proj_pick`**
  - @in [filtro]  @effect tela cheia; ⏎ entra no projeto (cd no shell atual)
  - @effect b/f/x gravam backup, favorito e imunidade na hora  @ret 1 sem terminal
  - @uses proj_rows proj_resolve proj_enter proj_info proj_backup proj_fav proj_lock proj_pad
- **`_pick_leave`**
  - @effect sai da tela alternativa
- **`_pick_load`**
  - @effect recarrega R (linhas de proj_rows, favoritos primeiro) e bk (chaves com backup próprio)
- **`_pick_draw`**
  - @effect redesenha a tela (sem limpar antes: sem piscar)

### `cmd/remove.sh`

- **`proj_remove`**
  - cmd/remove.sh - rm (lixeira com tar.gz) e undo
  - proj rm <nome[@versao]|.> [-k] [-y] [-P]
  -   padrão: cópia em $PROJ_BKP/removidos e apaga a pasta
  -   -k: só desregistra | -y: sem confirmação | -P: exclusão real (sem cópia)
  - @uses proj_resolve proj_is_imune proj_key_drop proj_regen proj_scan
- **`proj_undo`**
  - @in [ls|N]  N = posição na lista (1 = mais recente)
  - CORRIGIDO: o original usava "N) nome" como se fosse caminho; agora é array de caminhos.

### `cmd/ui.sh`

- **`proj_ui`**
  - @in (nada)  @effect tela alternativa; cada alteração grava em $PROJ_CFG e redesenha a prévia
  - @ret 1 se não houver terminal
- **`_ui_leave`**
  - @effect sai da tela alternativa e devolve o cursor
- **`_ui_set`**
  - @in chave valor  @effect grava via proj_config, recarrega config e cores, religa o atalho
- **`_ui_bind`**
  - @in tecla_antiga  @effect troca o bind do readline (só em shell interativo)
- **`_ui_change`**
  - @in -1|0|1  @effect altera a opção selecionada (bool alterna, enum cicla, num soma, 0 abre prompt)
- **`_ui_ask`**
  - @effect lê um valor digitado para a opção selecionada
- **`_ui_preview`**
  - @effect amostra com as cores e limites atuais
- **`_ui_draw`**
  - @effect redesenha a tela inteira (sem limpar antes: sem piscar)

### `cmd/vendor.sh`

- **`proj_vendor`**
  - cmd/vendor.sh - bibliotecas/dirs copiados em $PROJ_BASE/vendor
  - proj vendor add <projeto[@versao]|url|caminho> [nome] | ls | use <nome> | rm <nome>
  - @in add <projeto|url|caminho> [nome] | ls | use <nome> | rm <nome>
  - @effect copia/clona em $PROJ_BASE/vendor; use cria symlink em refs/  @ret 1 erro

## (raiz)

### `completion.sh`

- **`_proj_complete`** — _sem contrato_

## core

### `core/config.sh`

- **`proj_cfg_load`**
  - @out defaults + sobrescreve com $PROJ_CFG
- **`proj_init`**
  - @effect cria $PROJ_DIR e os .tsv vazios
- **`proj_boot`**
  - @effect 1x por sessão: config, dirs, migração v4
- **`proj_colors`**
  - @out PC_* (vazias se stdout não é tty). Paleta 256 cores. Chamado A CADA comando.
  - D=secundário  H=título  G/R/Y=ok/erro/aviso  C=categoria  M=destaque

### `core/tags.sh`

- **`proj_is_imune`**
  - @in tag  @g IMUNE_TAG  @ret 0 se a lista $1 contém a tag de imunidade
- **`proj_tag_add`**
  - @in lista tag  @out lista com tag (sem duplicar)
- **`proj_tag_del`**
  - @in lista tag  @out lista sem a tag

### `core/util.sh`

- **`proj_hum`**
  - @in bytes  @out stdout "1.5M"   (puro bash; trunca em vez de arredondar)
- **`proj_ago`**
  - @in epoch  @out stdout "3d" | agora | nunca   (sem fork de date)
- **`proj_fdate`**
  - @in epoch  @out stdout dd/mm/aaaa HH:MM | "-"   (printf %()T, sem fork)
- **`proj_kv`**
  - @in chave valor  @g PC_D PC_RST
- **`proj_jesc`**
  - @in string  @out stdout escapada p/ JSON   (sem fork)
- **`proj_notify`**
  - @in msg  @g NOTIFY
- **`proj_free_mb`**
  - @in [dir]  @out stdout MB livres
- **`proj_valid_name`**
  - @in string  @ret 0 se nome/versão válido ([A-Za-z0-9_][A-Za-z0-9._-]*)
- **`proj_valid_cat`**
  - @in string  @ret 0 se categoria válida (a/b/c, cada parte como um nome)
- **`proj_valid_tags`**
  - @in string  @ret 0 se vazia ou lista [A-Za-z0-9_.,-]+
- **`proj_bump`**
  - @in versao  @out stdout "1.0 -> 1.1"  @ret 1 se último campo não é número
- **`proj_lockrun`**
  - @in nome cmd...  @ret 99 se ocupado. Trava via mkdir (atômico); expira em 60min
- **`_proj_desc`**
  - @in arquivos... (passe um glob SEM aspas no padrão)  @out BK_F = lista do mais novo p/ o mais velho
  - Os nomes têm AAAAMMDD-HHMMSS, então a ordem alfabética do glob = cronológica.
  - Substitui `ls -1t | head/tail` (1-3 forks por chamada). @ret 1 se nada casou.
- **`proj_rule`**
  - @in [largura] [char]  @out linha horizontal (máx. 72 colunas)
- **`proj_sec`**
  - @in titulo [largura]  @out régua com o título embutido: "── titulo ─────"
- **`proj_pad`**
  - @in texto largura  @out REPLY texto preenchido por CARACTERES (printf %-Ns conta bytes)

## (raiz)

### `init.sh`

- **`_proj_src`** — _sem contrato_
- **`_proj_lazy`** — _sem contrato_

### `main.sh`

- **`proj`** — _sem contrato_

## nav

### `nav/resolve.sh`

- **`proj_find`**
  - @in nome [versao]  @out linhas do índice
- **`proj_here`**
  - @g PWD  @out linha do projeto que contém o diretório atual (o mais profundo)
- **`proj_resolve`**
  - @in alvo [q]  alvo: nome | nome@versao | nome@? (pergunta) | . (aqui) | - (anterior)
  - @out T_N T_V T_D T_K T_L   @ret 1 se não achou ($2=q -> silencioso)
  - (antes: 6+ forks de grep/cut/sed/cat; agora só proj_find/proj_here)
- **`proj_hook`**
  - @effect executa ./.proj-enter se HOOKS=1 e o arquivo é do usuário
- **`proj_enter`**
  - @in T_*  @effect cd, touch, atualiza ultimo/anterior, banner, hook, bg
  - (precisa rodar no shell atual: faz cd e source)
- **`proj_cd`**
  - @in alvo [versao]  @effect resolve (com rescan se falhar) e entra
- **`proj_path`**
  - @in [alvo]  @out stdout caminho

## store

### `store/readme.sh`

- **`proj_readme_set`**
  - @in dir chave valor  @effect edita o bloco <!-- proj --> de $dir/README.md
- **`proj_idx_set`**
  - @in dir coluna valor  @effect altera uma coluna do $PROJ_IDX (linha com $3==dir)

### `store/scan.sh`

- **`proj_parse`**
  - @in stdin: caminhos de README (1 por linha)  @out TSV: nome versao dir desc cat tags criado
- **`proj_readmes`**
  - @in raiz profundidade [stamp]  @out TSV (via proj_parse). Com stamp: só READMEs mais novos
- **`proj_taken`**
  - @in candidato usados antigos  @ret 0 se o nome já está ocupado
  - (sem subshell: declare -F / type -t direto)
- **`_proj_ident`**
  - @in nome  @out REPLY identificador seguro (bytes fora de [A-Za-z0-9_-] viram _)
- **`proj_regen`**
  - @effect reescreve $PROJ_FN (1 função atalho por projeto) e dá source
  - (antes: tr/sed/grep/wc por projeto; agora tudo em bash, 1 escrita só)
- **`proj_scan`**
  - @in [full]  @effect reconstrói index.tsv (incremental por padrão), atalhos, imunes, tamanhos
  - (antes: 1 grep -Fx por linha do índice; agora array associativo + 1 escrita)
- **`_proj_extras`**
  - @in tmp  acrescenta ao índice-em-construção as pastas de extras.tsv (fora de $PROJ_BASE)

### `store/size.sh`

- **`proj_size_calc`**
  - @in dir  @out stdout bytes (ignora node_modules e .cache)
- **`proj_size_refresh`**
  - @in chave dir [force]  @effect recalcula se o cache tem > 1h
- **`proj_size_all`**
  - @in [force]  @effect refresh de todos
  - (antes: awk+cut+date por projeto mesmo com cache válido; agora lê o estado 1x
  -  e só chama refresh nos vencidos)

### `store/state.sh`

- **`proj_st_get`**
  - @in chave  @out linha do estado
- **`proj_st_set`**
  - @in chave campo:valor...  @effect upsert da linha
- **`proj_touch`**
  - @in chave  @effect acesso=agora, acessos+1   (sem fork de date/cut)
- **`proj_key_drop`**
  - @in chave  @effect remove de estado/backup/imunes
- **`proj_key_rename`**
  - @in antiga nova  @effect renomeia chave nos 3 arquivos + pasta de backup
- **`proj_imune_sync`**
  - @effect reconstrói imunes.tsv a partir das tags; mantém os cujo dir sumiu
  - (antes: 1 awk por linha do imunes; agora: array associativo, 1 awk total)
- **`proj_rows`**
  - @out stdout: n v d desc cat tags criado | acesso acessos bytes fav

---
103 funções, 5 sem contrato.
