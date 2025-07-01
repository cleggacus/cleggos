{
  description = "Flake for your OS dev project";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          git
          nasm
          libgcc
          open-watcom-v2
          gnumake
          mtools       # for mcopy, mkfs.fat
          qemu
          bochs
          bash
        ];

        # Setup environment variables for your build tools
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
