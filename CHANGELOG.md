# Changelog

## 4.1.1
- Corrigido: `proj info` mostrava 1969 na data de modificação.

## 4.1.0
- Código modularizado em `core/`, `store/`, `nav/`, `backup/`, `cmd/` com carga lazy.
- Novo: `proj add` registra pasta existente sem mover nada.
- Corrigido: `proj undo` (lista de restauração usava nome em vez de caminho).
- Cores em 256 cores e réguas no `ls`/`info`.
- Menos forks: `date`, `cut`, `ls|head`, `basename` e outros viraram builtins do bash.
- Experimental: `projd` (C++), opcional, paridade testada com o shell.
