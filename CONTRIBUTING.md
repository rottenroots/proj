# Contribuindo

1. Faça um fork e crie uma branch (`git checkout -b minha-mudanca`).
2. Edite em `lib/proj/`. **Não edite `dist/`** (é gerado por `make build`).
3. Rode `make test` e, se tiver, `make lint`.
4. Abra um PR descrevendo o que mudou e por quê.

## Convenções

- Uma responsabilidade por arquivo: `core/` (puro, sem estado), `store/` (leitura/escrita dos .tsv),
  `nav/` (resolver e entrar em projetos), `backup/`, `cmd/` (um arquivo por comando).
- Toda função documenta o contrato em comentário: `@in`, `@out`, `@g` (globais lidas), `@effect`, `@ret`.
  Isso também serve de especificação para o port futuro para C++.
- Evite subshells e forks em caminhos quentes (`$(...)`, `cat | grep`, `cut` em loop).
  Prefira `read`, `${var%...}`, `printf '%(...)T'` e arrays associativos.
- Funções novas entram no `_proj_lazy` do `init.sh` e na lista `ORDER` do `Makefile`.
- Compatível com bash 4+ (Termux e Linux).
