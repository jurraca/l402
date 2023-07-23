{ pkgs ? import <nixpkgs> {} }:
with pkgs;
mkShell {
    buildInputs = [
        beam.packages.erlangR24.elixir
        protobuf
        libsodium
    ];
}
