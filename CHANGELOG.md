# Changelog

## 4.3.0
- Novo: `proj ui`, tela de configuração em tempo real (só teclado), com prévia ao vivo e atalho configurável (`PROJ_UI_KEY`).
- Novo: `proj pick`, seletor de projetos estilo mc (⏎ entra, `b` backup, `f` favorito, `x` imunidade, `/` filtra).
- Novo: toggle "Seletor no proj l" (`PROJ_PICK`): com ele ligado, `proj l` abre o seletor em terminal.
- Novo: `proj b all on|off`, backup automático em todos os projetos, sem alvo (`BKP_ALL`).
- Alinhamento do `ls` corrigido, reticências na descrição cortada e seções tituladas no `info`.

## 4.2.0
- `proj tag add|rm` aceita várias tags separadas por vírgula (`proj tag add a,b,c`).

## 4.1.1
- Corrigido: `proj info` mostrava 1969 na data de modificação.

## 4.1.0
- Código modularizado em `core/`, `store/`, `nav/`, `backup/`, `cmd/` com carga lazy.
- Novo: `proj add` registra pasta existente sem mover nada.
- Corrigido: `proj undo` (lista de restauração usava nome em vez de caminho).
- Cores em 256 cores e réguas no `ls`/`info`.
- Menos forks: `date`, `cut`, `ls|head`, `basename` e outros viraram builtins do bash.
- Experimental: `projd` (C++), opcional, paridade testada com o shell.
