{
  description = "Yapper - GUI for whisper-cli tool";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs = { self, nixpkgs }: {
    packages = let
      pkgs = nixpkgs.legacyPackages.${pkgs.system};
    in {
      default = pkgs.stdenv.mkDerivation {
        pname = "yapper";
        version = "1.0";

        src = ./.;

        nativeBuildInputs = [
          pkgs.python312
          pkgs.openai-whisper-cpp
          pkgs.ydotool
          pkgs.gtk4
          pkgs.gobject-introspection
          pkgs.gtk4.dev
          pkgs.python312Packages.pygobject3
        ];

        buildPhase = ''
          echo "Setting up environment..."
        '';

        installPhase = ''
          mkdir -p $out/bin
          cp -r ${self}/yapper.py $out/bin/
          cp -r ${self}/ggml-base.en.bin $out/bin/
        '';

        meta = with pkgs.lib; {
          description = "A GUI for the whisper-cli tool";
          license = licenses.mit;
          maintainers = [ maintainers.shlok-bhakta ];
        };
      };
    };
  };
}
