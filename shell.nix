{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  name = "yapper";
  buildInputs = [
    pkgs.python312
    pkgs.openai-whisper-cpp
    pkgs.dotool
    pkgs.gtk4
    pkgs.gobject-introspection
    pkgs.gtk4.dev
    pkgs.python312Packages.pygobject3
  ];
  
  shellHook = ''
    echo "Welcome to the yapper development environment!"
    echo "Python 3.12 and all necessary libraries for Whisper, GTK, and ydotool are ready to go."
    zsh # if you dont use zsh remove this line!
  '';
}

