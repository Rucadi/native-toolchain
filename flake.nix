{
  description = "Cmake with webOS toolchain";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11"; 
    x86_64-linux = {
      url = "file+https://github.com/openlgtv/buildroot-nc4/releases/latest/download/arm-webos-linux-gnueabi_sdk-buildroot.tar.gz";
      flake = false;
    };

    aarch64-linux = {
      url = "file+https://github.com/webosbrew/native-toolchain/releases/latest/download/arm-webos-linux-gnueabi_sdk-buildroot_linux-aarch64.tar.bz2";
      flake = false;
    };

    x86_64-darwin = {
      url = "file+https://github.com/webosbrew/native-toolchain/releases/latest/download/arm-webos-linux-gnueabi_sdk-buildroot_darwin-x86_64.tar.bz2";
      flake = false;
    };

    aarch64-darwin = {
      url = "file+https://github.com/webosbrew/native-toolchain/releases/latest/download/arm-webos-linux-gnueabi_sdk-buildroot_darwin-arm64.tar.bz2";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ...}@inputs:
    let
      allSystems = [
        "x86_64-linux" # 64bit AMD/Intel x86
        "aarch64-linux" # 64bit ARM
        "x86_64-darwin" # 64bit AMD/Intel macOS
        "aarch64-darwin" # 64bit ARM macOS
      ];

      forAllSystems = fn:
        nixpkgs.lib.genAttrs allSystems
        (system: fn { pkgs = import nixpkgs { inherit system; }; inherit system;});

      webOSToolchain = {system, fetchurl, runCommand}: let 
      in 
        runCommand "webos-toolchain" {} ''
          mkdir -p $out
          tar -xf ${inputs."${system}"} -C $out
          mv $out/arm-webos-linux-gnueabi_sdk-buildroot/* $out
          rm -rf $out/arm-webos-linux-gnueabi_sdk-buildroot

          # Patch sdl2-config cflags, most programs use <SDL2/SDL.h> instead of <SDL.h>
          # However, the toolchain include dir goes directly to inside SDL2 folder.
          ln -s $out/arm-webos-linux-gnueabi/sysroot/usr/include/SDL2 $out/arm-webos-linux-gnueabi/sysroot/usr/include/SDL2/ || true

          # link sdl2-config if not already in bin (inconsistent between versiosn of the toolchain)
          ln -s $out/arm-webos-linux-gnueabi/sysroot/usr/bin/sdl2-config $out/bin/sdl2-config || true
          rm -rf $out/arm-webos-linux-gnueabi_sdk-buildroot
        '';
    in {

      defaultPackage = forAllSystems ({ pkgs, system }: pkgs.callPackage webOSToolchain { inherit system; });

      devShells = forAllSystems ({ pkgs, system }: let 
          webOS = (pkgs.callPackage webOSToolchain { inherit system; });
      in
      {
        default = pkgs.mkShell {
          nativeBuildInputs = [ webOS pkgs.cmake ];         
          shellHook = ''
            source ${webOS}/environment-setup
            function webos_cmake_kit {
              mkdir -p .vscode
              echo '${builtins.toJSON [{ name = "webos-toolchain"; toolchainFile = "${webOS}/share/buildroot/toolchainfile.cmake";}]}' > .vscode/cmake-kits.json
            }
          '';
        };
      });
    };
}