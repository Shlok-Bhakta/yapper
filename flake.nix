{
  description = "Yapper - A Python-based transcription application";

  nixConfig = {
    extra-substituters = [
      "https://cuda-maintainers.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/24.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      perSystem = { system, ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              cudaSupport = true;
            };
          };

          pythonEnv = pkgs.python312.withPackages (ps: with ps; [
            pygobject3
          ]);

          whisperWithCuda = pkgs.openai-whisper-cpp.override {
            cudaSupport = true;
          };

          setupScript = pkgs.writeScriptBin "yapper-setup" ''
            #!/usr/bin/env bash
            CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/yapper"
            mkdir -p "$CONFIG_DIR"
            
            if [ ! -f "$CONFIG_DIR/ggml-base.en.bin" ]; then
              echo "Downloading Whisper model for first-time setup..."
              cd "$CONFIG_DIR"
              ${whisperWithCuda}/bin/whisper-cpp-download-ggml-model base.en
            fi
          '';
        in
        {
          packages.default = pkgs.stdenv.mkDerivation {
            pname = "yapper";
            version = "0.3.0";
            src = ./.;

            nativeBuildInputs = [
              pkgs.makeWrapper
              pkgs.imagemagick
              pkgs.gobject-introspection
              pkgs.wrapGAppsHook
            ];

            buildInputs = [
              pythonEnv
              whisperWithCuda
              pkgs.wtype
              pkgs.gtk4
              pkgs.gobject-introspection
              pkgs.gtk4.dev
              setupScript
              pkgs.cudatoolkit
              pkgs.linuxPackages.nvidia_x11
            ];

            installPhase = ''
              mkdir -p $out/bin
              mkdir -p $out/share/yapper
              mkdir -p $out/share/applications
              mkdir -p $out/share/icons/hicolor/scalable/apps
              mkdir -p $out/share/icons/hicolor/256x256/apps

              cp yapper.py $out/share/yapper/
              cp yapper-icon.svg $out/share/icons/hicolor/scalable/apps/yapper.svg
              ${pkgs.imagemagick}/bin/convert yapper-icon.svg -resize 256x256 $out/share/icons/hicolor/256x256/apps/yapper.png

              cat > $out/bin/yapper << EOF
              #!${pkgs.bash}/bin/bash
              export CUDA_PATH="${pkgs.cudatoolkit}"
              export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [
                pkgs.linuxPackages.nvidia_x11
                pkgs.cudatoolkit
              ]}"
              export EXTRA_LDFLAGS="-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib"
              export __NV_PRIME_RENDER_OFFLOAD=1
              export __GLX_VENDOR_LIBRARY_NAME="nvidia"
              ${setupScript}/bin/yapper-setup
              exec ${pythonEnv}/bin/python $out/share/yapper/yapper.py "\$@"
              EOF
              chmod +x $out/bin/yapper

              wrapProgram $out/bin/yapper \
                --prefix GI_TYPELIB_PATH : "$GI_TYPELIB_PATH" \
                --prefix PYTHONPATH : "${pythonEnv}/${pythonEnv.sitePackages}" \
                --prefix PATH : ${pkgs.lib.makeBinPath [ setupScript whisperWithCuda pkgs.cudatoolkit ]}

              cat > $out/share/applications/yapper.desktop << EOF
              [Desktop Entry]
              Version=1.0
              Type=Application
              Name=Yapper
              Comment=Audio Transcription Tool
              Exec=$out/bin/yapper
              Icon=yapper
              Terminal=false
              Categories=Audio;Utility;Transcription;
              Keywords=audio;transcription;whisper;speech;
              EOF
            '';
          };

          devShells.default = pkgs.mkShell {
            name = "yapper";
            buildInputs = [
              pkgs.python312
              whisperWithCuda
              pkgs.wtype
              pkgs.gtk4
              pkgs.gobject-introspection
              pkgs.gtk4.dev
              pkgs.python312Packages.pygobject3
            ];
            
            shellHook = ''
              echo "Welcome to the yapper development environment!"
              echo "Python 3.12 and all necessary libraries for Whisper, GTK, and ydotool are ready to go."
              echo "CUDA support is enabled for whisper-cpp using the system-wide CUDA installation"
              zsh
            '';
          };
        };
    };
}
