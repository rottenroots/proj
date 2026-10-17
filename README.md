# proj

Gerenciador de projetos em shell: registra, versiona, busca, faz backup e limpa seus projetos
a partir de um cabeçalho `<!-- proj ... -->` no README de cada um. Feito para Termux e Linux (bash 4+).

## Instalação

    git clone <url> && cd proj
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

## Estrutura

    bin/proj            entrypoint fino (scripts)
    lib/proj/
      init.sh           carrega o core e registra o resto como lazy
      core/             config, util, tags (sem estado)
      store/            readme, state, scan, size (leitura/escrita dos .tsv)
      nav/              resolver alvo e entrar no projeto
      backup/           backups periódicos e limpeza
      cmd/              um arquivo por comando
      main.sh           dispatcher  |  completion.sh  autocompletar
    tests/              smoke.sh, bench.sh
    docs/               documentação

## Desenvolvimento

    make test      # sintaxe + testes (em HOME temporário)
    make build     # gera dist/proj.sh (arquivo único)
    make bench     # tempo de carga: original x modular x bundle

## Licença

MIT

## Núcleo nativo (experimental)

`src/main.cpp` (`make cpp`) implementa `rows`, `find`, `here` e `st` com saída idêntica ao shell
(`make parity`). Em testes com 3000 projetos não houve ganho sobre o awk, então fica desligado
por padrão; o próximo candidato é o `scan`.

## Núcleo nativo (experimental)

`src/main.cpp` (`make cpp`) implementa `rows`, `find`, `here` e `st` com saída idêntica ao shell
(`make parity`). Em testes com 3000 projetos não houve ganho sobre o awk, então fica desligado
por padrão; o próximo candidato é o `scan`.
