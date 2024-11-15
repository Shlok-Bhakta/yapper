# Yapper

https://github.com/user-attachments/assets/dfa57316-8f05-484d-ac5d-91f51a0af948


Welcome to my project, **Yapper**! It's a super simple speech-to-text application, so that's why it's a little derpy lol. The project is just a 200-line Python script written by Claude and ChatGPT. Its pretty much a minimal GTK wrapper for [openai-whisper-cpp](https://github.com/ggerganov/whisper.cpp). Also thank you so much to [SeungheonOh](https://github.com/SeungheonOh) for helping me with the nix flake!

## Requirements
- NixOS System (works on other distros please make an issue and ill try my best to help)
- Tested Only on Hyprland
- Nvidia GPU With CUDA Support on a System Level (nvidia-smi shows CUDA support)
(make an issue if you want to use this without an Nvidia GPU ill try my best to help)

## Description

The idea behind Yapper is simple: I wanted to click a button, speak into my microphone, and have everything transcribed automatically using GPT's Whisper model. It works fairly well, though it's ~~bit slow~~ pretty fast with cuda now, so don’t expect too much. If there are bugs, I probably can’t fix them right away (do leave an issue though), but I will patch any that I run into personally.   

Here’s the flow:
1. Speak into the microphone.
2. Get a rough transcription (think of it as a research paper or whatever).
3. Throw it into ChatGPT to refine it, and ChatGPT will clean things up, add punctuation, and make it more legible.

In the end, you have your thoughts and ideas—just dictated instead of typed out for hours while smashing your head against the desk.

## Features

- Speech-to-text transcription using Whisper
- Use ChatGPT to refine your transcriptions

## Installation

Since I’m on NixOS, I’ll leave a guide for how to install this on NixOS here. If you want to style it like mine, I’ve set it up with the Catppuccin theme. I’ll figure out how to share that too.

Thanks to [SeungheonOh](https://github.com/SeungheonOh)

Add the following to your `flake.nix`
```nix
    inputs = {
        ...
        yapper = {
            url = "github:Shlok-Bhakta/yapper";
            inputs.nixpkgs.follows = "nixpkgs"; # optional
        };
        ...
    };
```

In your `home.nix` add the following
```nix
    home.packages = [
        ...
        inputs.yapper.packages."${pkgs.system}".default
        ...
    ];
```

rebuild your system and enjoy!

If you have any questions feel free to open an issue and ill try my best to help!

## Contributing

Don’t expect much support, but if you have cool ideas, feel free to open a pull request. I am open to contributions and excited to see if anyone actually contributes to this project. If you do, feel free to give it a star! 😄

Note: I didn’t write all of this myself, I just needed a quick solution, and all the other ones out there weren’t quite right.

## Testing
Make sure you have git installed

Then clone the repo
```bash
git clone https://github.com/Shlok-Bhakta/yapper.git
cd yapper
```
### General (UNTESTED)
then make sure to have python 3.12 installed with your distros package manager or [their website](https://www.python.org/downloads/release/python-3120/)

install [openai-whisper-cpp](https://github.com/ggerganov/whisper.cpp) then run
```bash
whisper-cpp-download-ggml-model base.en
```
This will download the model to your machine in the current dir that the command was run
```bash
python yapper.py
```
### Nix OS
run
```bash
nix-shell
```
run
```bash
whisper-cpp-download-ggml-model base.en
```
This will download the model to your machine in the current dir that the command was run
```bash
python yapper.py
```


## License

MIT License. See the [LICENSE](LICENSE) file for more information.

---

Thank you for coming to my TED Talk! 🎤 and again, thank you to [SeungheonOh](https://github.com/SeungheonOh) for helping me out!