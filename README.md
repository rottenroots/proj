# proj

Gerenciador de projetos em shell: registra, versiona, busca, faz backup e limpa seus projetos
a partir de um cabeçalho `<!-- proj ... -->` no README de cada um. Feito para Termux e Linux (bash 4+).

## Instalação

    git clone https://github.com/rottenroots/proj && cd proj
    ./install.sh            # copia para ~/.local/share/proj
    ./install.sh --dev      # symlink, para desenvolver

Abra um novo terminal. O instalador adiciona uma linha ao `~/.bashrc` (e `./install.sh --uninstall` remove).

## Uso rápido

    proj n meuapp -c web -t node -d "minha ideia"   # cria e entra
    proj l                                          # lista
    meuapp                                          # atalho direto para o projeto
    proj -                                          # volta ao anterior
    proj b on . 12h 5                               # backup a cada 12h, mantém 5
    proj lock .                                     # imune a rm/clean
    proj help                                       # tudo

## Interface interativa

    proj ui          # configuração ao vivo: ↑↓ move, ←→ altera, ⏎ edita, u desfaz, q sai
    proj pick        # seletor de projetos: ⏎ entra, i info, / filtra
    proj b all on    # backup automático em todos os projetos

No `proj pick`: `b` liga/desliga backup, `f` fixa (★) e `x` alterna a imunidade (🔒) do projeto
selecionado. Não há `rm` no seletor, de propósito.

Seleção múltipla: `espaço` marca (✓), `a` marca todos os visíveis, `c` limpa. As ações `b`, `f`, `x`,
`t` (adiciona tags), `T` (remove tags) e `z` (arquiva) valem para todos os marcados, ou só para o
selecionado se nada estiver marcado. O arquivamento pede confirmação e ignora projetos imunes.

Em `proj ui` dá para ligar "Seletor no proj l" (o `proj l` passa a abrir o seletor; com flags
como `-a` ou `-j` continua a tabela) e escolher um atalho de teclado (`Ctrl+G`, `Ctrl+O`, `Ctrl+P`)
para abrir a própria tela.

## Comparar

    proj i app@1.0 app@1.1     # metadados lado a lado (diferenças em amarelo)
    proj i app -b              # o que mudou desde o último backup (+ novo, ~ modificado, - removido)
    proj i app -b3 -n 50       # contra o 3º backup mais recente, até 50 linhas (-n 0 = todas)

O limite padrão é 20 linhas (`proj config CMP_LINES N` ou a tela `proj ui`). A comparação com o backup usa
data e tamanho, sem extrair nada; um arquivo editado que manteve o mesmo tamanho no mesmo minuto não aparece.

## Estrutura

    bin/proj            entrypoint fino (scripts)
    lib/proj/
      init.sh           carrega o core e registra o resto como lazy
      core/             config, util, tags (sem estado)
      store/            readme, state, scan, size (leitura/escrita dos .tsv)
      nav/              resolver alvo e entrar no projeto
      backup/           backups periódicos e limpeza
      cmd/              um arquivo por comando (inclui ui.sh e pick.sh, as telas interativas)
      main.sh           dispatcher  |  completion.sh  autocompletar
    tests/              smoke.sh, bench.sh
    docs/               documentação

## Desenvolvimento

    make test      # sintaxe + testes (em HOME temporário)
    make build     # gera dist/proj.sh (arquivo único)
    make bench     # tempo de carga: original x modular x bundle

## Núcleo nativo (experimental)

`src/main.cpp` (`make cpp`) implementa `rows`, `find`, `here` e `st` com saída idêntica ao shell
(`make parity`). Em testes com 3000 projetos não houve ganho sobre o awk, então fica desligado
por padrão; o próximo candidato é o `scan`.

> **Termux:** não confunda com o pacote `proj` do `pkg` (biblioteca de projeções cartográficas). Este projeto é instalado por `./install.sh`.

## Licença

MIT
