{
  description = "Flake for your OS dev project";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        system = system;
        config = {
          allowUnfree = true;
        };
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          git
          nasm
          libgcc
          open-watcom-v2
          gnumake
          mtools
          qemu
          bochs
          bash
        ];

        shellHook = ''
          export ASM=nasm
          export CC=gcc
          export CC16=wcc
          export LD16=wlink
          echo "Dev shell ready for OS project build"
        '';
      };
    };
}
