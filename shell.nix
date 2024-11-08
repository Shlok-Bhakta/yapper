{ pkgs ? import <nixpkgs> {} }:

let
  whisperWithCuda = pkgs.openai-whisper-cpp.override {
    cudaSupport = true;
  };
in
pkgs.mkShell {
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
}
