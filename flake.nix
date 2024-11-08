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
        
        pythonEnv = pkgs.python312.withPackages (ps: with ps; [
          pygobject3
        ]);
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "yapper";
          version = "0.1.0";
          src = ./.;

          nativeBuildInputs = [
            pkgs.makeWrapper
            pkgs.imagemagick # For converting SVG to PNG
          ];

          buildInputs = [
            pythonEnv
            pkgs.openai-whisper-cpp
            pkgs.dotool
            pkgs.gtk4
            pkgs.gobject-introspection
            pkgs.gtk4.dev
          ];

          installPhase = ''
            # Create necessary directories
            mkdir -p $out/bin
            mkdir -p $out/share/yapper
            mkdir -p $out/share/applications
            mkdir -p $out/share/icons/hicolor/scalable/apps
            mkdir -p $out/share/icons/hicolor/256x256/apps
            
            # Download the model during build
            ${pkgs.openai-whisper-cpp}/bin/whisper-cpp-download-ggml-model base.en
            mv base.en.bin $out/share/yapper/

            # Install the Python script
            cp yapper.py $out/share/yapper/
            
            # Install icons
            cp yapper-icon.svg $out/share/icons/hicolor/scalable/apps/yapper.svg
            ${pkgs.imagemagick}/bin/convert yapper-icon.svg -resize 256x256 $out/share/icons/hicolor/256x256/apps/yapper.png

            # Create desktop entry
            cat > $out/share/applications/yapper.desktop << EOF
            [Desktop Entry]
            Version=1.0
            Type=Application
            Name=Yapper
            Comment=Audio Transcription Tool
            Exec=yapper
            Icon=yapper
            Terminal=false
            Categories=Audio;Utility;Transcription;
            Keywords=audio;transcription;whisper;speech;
            EOF
            
            # Create wrapper script
            makeWrapper ${pythonEnv}/bin/python $out/bin/yapper \
              --add-flags "$out/share/yapper/yapper.py" \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.openai-whisper-cpp pkgs.dotool ]} \
              --set WHISPER_MODEL "$out/share/yapper/base.en.bin" \
              --prefix GI_TYPELIB_PATH : "${pkgs.gtk4}/lib/girepository-1.0" \
              --prefix GI_TYPELIB_PATH : "${pkgs.gtk4.dev}/lib/girepository-1.0"

            # Make the wrapper script executable
            chmod +x $out/bin/yapper
          '';

          meta = with pkgs.lib; {
            description = "A Python-based audio transcription application using whisper.cpp";
            longDescription = ''
              Yapper is a simple audio transcription tool that uses whisper.cpp
              for efficient, offline speech recognition. It provides both a
              command-line interface and a GTK-based graphical interface.
            '';
            homepage = "https://github.com/Shlok-Bhakta/yapper";
            license = licenses.mit;  # Adjust according to your license
            platforms = platforms.linux;
            maintainers = with maintainers; [ /* add your maintainer name here */ ];
          };
        };

        devShells.default = pkgs.mkShell {
          name = "yapper";
          buildInputs = [
            pythonEnv
            pkgs.openai-whisper-cpp
            pkgs.dotool
            pkgs.gtk4
            pkgs.gobject-introspection
            pkgs.gtk4.dev
          ];
          
          shellHook = ''
            echo "Welcome to the yapper development environment!"
            echo "Python 3.12 and all necessary libraries for Whisper, GTK, and ydotool are ready to go."
            zsh
          '';
        };
      }
    );
}