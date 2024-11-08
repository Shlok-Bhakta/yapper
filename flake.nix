{
  description = "Yapper - A Python-based transcription application";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Create a wrapper script that handles first-time setup
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

      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "yapper";
          version = "0.1.0";
          src = ./.;

          nativeBuildInputs = [
            pkgs.makeWrapper
            pkgs.imagemagick
          ];

          buildInputs = [
            pkgs.openai-whisper-cpp
            pkgs.dotool
            pkgs.gtk4
            pkgs.gobject-introspection
            pkgs.gtk4.dev
            pkgs.python312
            pkgs.openai-whisper-cpp
            pkgs.python312Packages.pygobject3
            setupScript
          ];

          installPhase = ''
            # Create necessary directories
            mkdir -p $out/bin
            mkdir -p $out/share/yapper
            mkdir -p $out/share/applications
            mkdir -p $out/share/icons/hicolor/scalable/apps
            mkdir -p $out/share/icons/hicolor/256x256/apps

            # Install the Python script
            cp yapper.py $out/share/yapper/
            
            # Install icons
            cp yapper-icon.svg $out/share/icons/hicolor/scalable/apps/yapper.svg
            ${pkgs.imagemagick}/bin/convert yapper-icon.svg -resize 256x256 $out/share/icons/hicolor/256x256/apps/yapper.png

            # Create launcher script
            cat > $out/bin/yapper << EOF
            #!/usr/bin/env bash
            # Run setup script first
            yapper-setup
            
            # Set model path
            export WHISPER_MODEL="\$HOME/.local/share/yapper/ggml-base.en.bin"
            
            # Run the actual program
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
            
            # Wrap the setup script
            makeWrapper ${setupScript}/bin/yapper-setup $out/bin/yapper-setup \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.openai-whisper-cpp ]}

            # Wrap the main script
            wrapProgram $out/bin/yapper \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.openai-whisper-cpp pkgs.dotool ]} \
              --prefix GI_TYPELIB_PATH : "${pkgs.gtk4}/lib/girepository-1.0" \
              --prefix GI_TYPELIB_PATH : "${pkgs.gtk4.dev}/lib/girepository-1.0"
          '';

          meta = with pkgs.lib; {
            description = "A Python-based audio transcription application using whisper.cpp";
            longDescription = ''
              Yapper is a simple audio transcription tool that uses whisper.cpp
              for efficient, offline speech recognition. It provides both a
              command-line interface and a GTK-based graphical interface.
            '';
            homepage = "https://github.com/Shlok-Bhakta/yapper";
            license = licenses.mit;
            platforms = platforms.linux;
            maintainers = with maintainers; [ "Shlok Bhakta" ];
          };
        };
      }
    );
}