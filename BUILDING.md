# Compilação (opcional)

O `proj` funciona 100% em shell. O núcleo nativo `projd` é experimental e **não é necessário**.

    pkg install clang make     # Termux  (Debian/Ubuntu: apt install g++ make)
    make cpp                   # ou: bash scripts/build-native.sh
    make parity                # confere: saída idêntica à do shell

- Compila na própria máquina (ARM64, x86_64...); sem binários pré-compilados.
- Com `bin/projd` presente, `rows`, `find`, `here` e `st` passam a usá-lo. Para desligar: `rm bin/projd`.
- Requisitos: C++17 (clang 10+ ou gcc 8+).
