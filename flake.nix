{
  description = "Yapper - A Python-based transcription application";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

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
          ];

          buildInputs = [
            pkgs.python312
            whisperWithCuda
            pkgs.wtype
            pkgs.gtk4
            pkgs.gobject-introspection
            pkgs.gtk4.dev
            pkgs.python312Packages.pygobject3
          ];

          installPhase = ''
            mkdir -p $out/bin
            mkdir -p $out/share/yapper
            mkdir -p $out/share/applications
            mkdir -p $out/share/icons/hicolor/scalable/apps
            mkdir -p $out/share/icons/hicolor/256x256/apps

            # Install Python script and icons
            cp yapper.py $out/share/yapper/
            cp yapper-icon.svg $out/share/icons/hicolor/scalable/apps/yapper.svg
            ${pkgs.imagemagick}/bin/convert yapper-icon.svg -resize 256x256 $out/share/icons/hicolor/256x256/apps/yapper.png

            # Create launcher script
            cat > $out/bin/yapper << EOF
            #!/usr/bin/env bash
            yapper-setup
            
            ${pkgs.python312}/bin/python $out/share/yapper/yapper.py
            EOF
            chmod +x $out/bin/yapper

            # Create desktop entry
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

          meta = with pkgs.lib; {
            description = "A Python-based audio transcription application using whisper.cpp";
            homepage = "https://github.com/Shlok-Bhakta/yapper";
            license = licenses.mit;
            platforms = platforms.linux;
            maintainers = with maintainers; [ "Shlok Bhakta" ];
          };
        };
      }
    );
}
