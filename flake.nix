{
  description = "GraceOS: hybrid 386 kernel dev environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      # i686-elf GCC and binutils with --with-arch=i386, so the compiler's
      # defaults (and libgcc) never assume anything newer than a plain 386.
      cross = import nixpkgs {
        localSystem = system;
        crossSystem = {
          config = "i686-elf";
          libc = null;
          gcc.arch = "i386";
        };
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          cross.buildPackages.gcc
          cross.buildPackages.binutils
          pkgs.nasm
          pkgs.gnumake
          pkgs.qemu
          pkgs.gdb
        ];
      };
    };
}
