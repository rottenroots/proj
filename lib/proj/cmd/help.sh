# cmd/help.sh - proj help
proj_help() {
  cat <<'AJUDA'
proj <nome[@versao]>           abre o projeto (atalho direto: <nome> [versao])
proj -                         volta ao projeto anterior   | proj nome@?  escolhe a versão
proj l  [filtro] [-s|-r|-a] [-p] [-f] [-j|-t]
                               lista (-s tamanho, -r recentes, -a A-Z, -p caminho,
                               -f recalcula tamanhos, -j json, -t tsv)
proj i  [alvo] [-j]            informações completas do projeto
proj add [pasta] [nome] [versao] [-c cat] [-t tags] [-d "desc"]
                               registra uma pasta que já existe (não move nada)
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
