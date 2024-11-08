{
  description = "Yapper - GUI for whisper-cli tool";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.defaultApp = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in pkgs.mkShell {
      name = "yapper";
      buildInputs = [
        pkgs.python312
        pkgs.openai-whisper-cpp
        pkgs.ydotool
        pkgs.gtk4
        pkgs.gobject-introspection
        pkgs.gtk4.dev
        pkgs.python312Packages.pygobject3
      ];

      shellHook = ''
        echo "Setting up Yapper environment..."
        
        # Download the Whisper model if not already present
        if [ ! -f ggml-base.en.bin ]; then
          whisper-cpp-download-ggml-model base.en
        fi

        # Run the application
        python yapper.py
      '';
    };
  };
}
