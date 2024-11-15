import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk, GLib
import subprocess
import threading
from multiprocessing import Value
import signal
import os

def get_model_path():
    config_dir = os.environ.get('XDG_CONFIG_HOME', os.path.expanduser('~/.config'))
    return os.path.join(config_dir, 'yapper', 'ggml-base.en.bin')
# Constants for Whisper model and settings
MODEL_PATH = get_model_path()
RATE = 16000
CHUNK = 256

# Track the current transcription process
transcription_thread = None
is_transcribing = False
whisper_process = None

def get_microphones():
    """Retrieve list of available capture devices from whisper-cpp-stream."""
    result = subprocess.run(["whisper-cpp-stream"], capture_output=True, text=True)
    lines = result.stderr.splitlines()
    devices = []
    for line in lines:
        if "Capture device #" in line:
            devices.append(line.strip().split(": ")[-1].strip("'"))
    return devices if devices else ["No devices found"]

def type_text(text):
    """Send text to dotool for typing."""
    if not text.strip():
        return
    try:
        cmd = f'wtype "{text}"'
        subprocess.run(['sh', '-c', cmd], check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error using dotool: {e}")

def transcribe_audio(mic_id, stop_flag):
    """Run whisper-cpp-stream with the selected microphone and clean output."""
    global is_transcribing, whisper_process
    try:
        command = ["whisper-cpp-stream", "-m", MODEL_PATH, "-c", str(mic_id)]
        whisper_process = subprocess.Popen(command, stdout=subprocess.PIPE, text=True)
        for line in whisper_process.stdout:
            if stop_flag.value:
                whisper_process.send_signal(signal.SIGINT)
                break
            if line.strip() and not any(x in line for x in ["[", "]", "(", "action", "init:"]):
                cleaned_text = line.strip()
                GLib.idle_add(type_text, cleaned_text)
    except Exception as e:
        print(f"Error in transcription process: {e}")
    finally:
        if whisper_process and whisper_process.poll() is None:
            whisper_process.send_signal(signal.SIGINT)
            whisper_process.wait()
        is_transcribing = False
def stopTranscribe(button):
    global is_transcribing, transcription_thread, stop_flag
    transcription_thread.join()
    stop_flag.value = False
    is_transcribing = False
    button.set_label("Start")
    button.get_style_context().remove_class("yellow-button")
    return False

def toggle_transcription(button, combo):
    """Toggle transcription on/off when the button is clicked."""
    global is_transcribing, transcription_thread, stop_flag
    if is_transcribing:
        stop_flag.value = True
        button.get_style_context().remove_class("red-button")
        button.get_style_context().add_class("yellow-button")
        button.set_label("Stopping...")
        GLib.timeout_add(300, stopTranscribe, button)
    else:
        mic_id = combo.get_active()
        if mic_id != -1:
            is_transcribing = True
            stop_flag = Value('b', False)  # Create a shared stop flag
            button.set_label("Stop")
            button.get_style_context().add_class("red-button")
            transcription_thread = threading.Thread(target=transcribe_audio, args=(mic_id, stop_flag), daemon=True)
            transcription_thread.start()

def on_activate(app):
    window = Gtk.ApplicationWindow(application=app)
    window.set_title("yapadabadoo")
    window.set_modal(True)

    # Set window position (assumes Hyprland setup)
    display = Gdk.Display.get_default()
    monitors = display.get_monitors()
    if monitors.get_n_items() > 0:
        monitor = monitors.get_item(0)
        geometry = monitor.get_geometry()
        window_width = 400
        window_height = 50
        x = (geometry.width - window_width) // 2
        y = geometry.height - window_height - 50
        window.set_default_size(window_width, window_height)
        surface = window.get_surface()
        if surface:
            surface.set_position(x, y)

    hbox = Gtk.Box(spacing=6, orientation=Gtk.Orientation.HORIZONTAL)
    window.set_child(hbox)
    hbox.set_margin_start(6)
    hbox.set_margin_end(6)
    hbox.set_margin_top(6)
    hbox.set_margin_bottom(6)

    # Microphone dropdown
    mic_store = Gtk.ListStore(str)
    mics = get_microphones()
    print(mics)
    for mic in mics:
        mic_store.append([mic])

    mic_combo = Gtk.ComboBox(model=mic_store)
    renderer_text = Gtk.CellRendererText()
    mic_combo.pack_start(renderer_text, True)
    mic_combo.add_attribute(renderer_text, "text", 0)
    mic_combo.set_active(0)
    dropdown_width = 200
    mic_combo.set_size_request(dropdown_width, -1)
    hbox.append(mic_combo)

    # Start/Stop Button
    button = Gtk.Button(label="Start")
    button.connect("clicked", toggle_transcription, mic_combo)
    hbox.append(button)

    # Style for red and yellow buttons
    css = """
    .red-button {
        background-color: #ff4d4d;
        color: white;
    }
    .yellow-button {
        background-color: #ffff66;
        color: black;
    }
    """
    style_provider = Gtk.CssProvider()
    style_provider.load_from_data(css.encode())
    Gtk.StyleContext.add_provider_for_display(
        Gdk.Display.get_default(), style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )

    window.set_resizable(False)
    window.set_deletable(False)
    window.present()

def on_shutdown(app):
    global is_transcribing, stop_flag, whisper_process
    is_transcribing = False
    stop_flag.value = True
    if whisper_process:
        whisper_process.terminate()
        whisper_process.wait()

app = Gtk.Application(application_id="com.example.yapadabadoo")
app.connect('activate', on_activate)
app.connect('shutdown', on_shutdown)

app.run(None)