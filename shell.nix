{ pkgs ? import <nixpkgs> {} }:
with pkgs;
mkShell {
    buildInputs = [
        beam.packages.erlangR24.elixir
        protobuf
        libsodium
    ];
    shellHook = ''
        mix escript.install hex protobuf

        export PATH=~/.mix/escripts:$PATH
    '';
}
