{
  description = "Yapper - A Python-based transcription application";

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
            config.allowUnfree = true;
          };

          pythonEnv = pkgs.python312.withPackages (ps: with ps; [
            pygobject3
            # Add other Python dependencies here
          ]);

          setupScript = pkgs.writeScriptBin "yapper-setup" ''
            #!/usr/bin/env bash
            MODEL_DIR="$HOME/.local/share/yapper"
            MODEL_PATH="$MODEL_DIR/ggml-base.en.bin"

            if [ ! -f "$MODEL_PATH" ]; then
              echo "Downloading Whisper model for first-time setup..."
              mkdir -p "$MODEL_DIR"
              ${pkgs.openai-whisper-cpp}/bin/whisper-cpp-download-ggml-model base.en
              mv ggml-base.en.bin "$MODEL_PATH"
            fi
          '';

          whisperWithCuda = pkgs.openai-whisper-cpp.override {
            cudaSupport = true;
          };
        in
        {
          packages.default = pkgs.stdenv.mkDerivation {
            pname = "yapper";
            version = "0.1.0";
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
              ${setupScript}/bin/yapper-setup
              exec ${pythonEnv}/bin/python $out/share/yapper/yapper.py
              EOF
              chmod +x $out/bin/yapper

              wrapProgram $out/bin/yapper \
                --prefix GI_TYPELIB_PATH : "$GI_TYPELIB_PATH" \
                --prefix PYTHONPATH : "${pythonEnv}/${pythonEnv.sitePackages}" \
                --prefix PATH : ${pkgs.lib.makeBinPath [ setupScript ]}

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
        };
    };
}
