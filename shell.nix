{ pkgs ? import <nixpkgs> {} }:
with pkgs;
mkShell {
    buildInputs = [
        beam.packages.erlangR24.elixir
        protobuf
        libsodium

        # uncomment if you want to run a node locally
        # lnd
        # bitcoin
    ];
}
