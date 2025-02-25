import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk, GLib
import subprocess
import threading
from multiprocessing import Value
import signal
import os
import re

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

def clean_text(text):
    """Clean and normalize text before typing."""
    # Strip extra whitespace
    text = text.strip()
    if not text:
        return ""
        
    # Capitalize first letter of sentences
    if len(text) > 0 and text[0].isalpha():
        text = text[0].upper() + text[1:]
        
    # Fix common transcription artifacts
    text = text.replace(" i ", " I ")
    text = text.replace(" i'm ", " I'm ")
    text = text.replace(" i'll ", " I'll ")
    text = text.replace(" i'd ", " I'd ")
    text = text.replace(" i've ", " I've ")
    
    # Remove unnecessary spaces before punctuation
    for punct in ['.', ',', '!', '?', ':', ';']:
        text = text.replace(f' {punct}', punct)
    
    # Fix adjacent repeated words (like "years years")
    words = text.split()
    if len(words) > 1:
        i = 1
        while i < len(words):
            if words[i].lower() == words[i-1].lower():
                words.pop(i)
            else:
                i += 1
        text = " ".join(words)
    
    # Fix period spacing issues (like "mines.I" -> "mines. I")
    for punct in ['.', '!', '?']:
        # Look for punctuation followed immediately by a letter
        for i in range(len(text)-1):
            if text[i] in punct and text[i+1].isalpha():
                text = text[:i+1] + " " + text[i+1:]
                
    return text

def type_text(text):
    """Send text to wtype for typing."""
    if not text.strip():
        return
    
    # Clean and normalize the text
    text = clean_text(text)
    
    try:
        # Escape quotes and other special characters for shell
        escaped_text = text.replace('"', '\\"').replace('$', '\\$').replace('`', '\\`')
        cmd = f'wtype "{escaped_text}"'
        subprocess.run(['sh', '-c', cmd], check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error using wtype: {e}")

def transcribe_audio(mic_id, stop_flag):
    global is_transcribing, whisper_process
    buffer = ""
    last_sent_sentence = ""
    pending_sentences = []  # Queue for sentences waiting to be sent
    pending_timer = None    # Timer for pending sentence processing
    
    def send_sentence(text):
        """Send a sentence after deduplication processing."""
        nonlocal last_sent_sentence
        if text:
            # Check for duplicated text at boundaries
            if last_sent_sentence:
                # Get the last word of previous sentence
                prev_words = last_sent_sentence.strip().split()
                if prev_words:
                    last_word = prev_words[-1].rstrip('.!?:;,')
                    
                    # Get first word of current sentence
                    new_words = text.strip().split()
                    if new_words and len(new_words) > 1:  # Ensure there are at least 2 words
                        first_word = new_words[0].rstrip('.!?:;,')
                        
                        # If duplication detected, remove the first word
                        if last_word.lower() == first_word.lower():
                            text = " ".join(new_words[1:])
            
            GLib.idle_add(type_text, text)
            last_sent_sentence = text
    
    def process_pending_sentences():
        """Process any sentences waiting in the queue."""
        nonlocal pending_sentences, pending_timer
        if pending_sentences:
            sentence = pending_sentences.pop(0)
            send_sentence(sentence)
        pending_timer = None
        return False  # Don't repeat the timer
    
    try:
        command = ["whisper-cpp-stream", "-m", MODEL_PATH, "-c", str(mic_id)]
        whisper_process = subprocess.Popen(command, stdout=subprocess.PIPE, text=True)
        for line in whisper_process.stdout:
            if stop_flag.value:
                whisper_process.send_signal(signal.SIGINT)
                break
            
            # Filter out common artifacts and status messages including "..." and "…"
            if line.strip() and not any(x in line for x in ["[", "]", "(", "action", "init:", "...", "…"]):
                cleaned_text = line.strip()
                
                # Handle first letter getting cut off issue
                if not buffer:
                    # If buffer is empty, don't add leading space
                    buffer = cleaned_text
                else:
                    # Otherwise add space between segments
                    buffer += " " + cleaned_text
                
                # Add 100ms delay to give time for whisper-cpp-stream to process audio fully
                # This helps prevent words from getting cut off like "yearn" becoming "earn"
                # Replace consecutively repeated words like "years years"
                buffer = re.sub(r'\b(\w+)\s+\1\b', r'\1', buffer)

                # Sentence boundary detection
                while True:
                    last_punct = max(
                        buffer.rfind('.'),
                        buffer.rfind('!'),
                        buffer.rfind('?'),
                        buffer.rfind(':')  # For question/answer patterns
                    )
                    
                    # Minimum sentence length check to avoid premature sending
                    if last_punct != -1 and last_punct >= 3:  # At least 3-character sentences
                        sentence = buffer[:last_punct+1]
                        
                        # Make sure there is a space after the period to fix "mines.I" issue becoming "mines. I"
                        remaining = buffer[last_punct+1:].lstrip()
                        
                        # If there's a pending timer, cancel it
                        if pending_timer:
                            GLib.source_remove(pending_timer)
                            pending_timer = None
                        
                        # Add to pending sentences queue for delayed processing
                        pending_sentences.append(sentence)
                        
                        # Start a new timer to allow for model self-corrections
                        pending_timer = GLib.timeout_add(800, process_pending_sentences)
                        
                        buffer = remaining
                    else:
                        break
    except Exception as e:
        print(f"Error in transcription process: {e}")
    finally:
        # Process any pending sentences immediately
        if pending_sentences:
            for sentence in pending_sentences:
                send_sentence(sentence)
        
        # Flush remaining buffer
        if buffer.strip():
            send_sentence(buffer.strip())
        
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
    window.set_title("Yapper STT")
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
    
    # Set up keyboard shortcut handling - keeping this functionality without UI changes
    key_controller = Gtk.EventControllerKey()
    window.add_controller(key_controller)
    
    # Simple keyboard shortcut handler
    def on_key_press(controller, keyval, keycode, state, button, mic_combo):
        # Check for Ctrl+Space
        ctrl = (state & Gdk.ModifierType.CONTROL_MASK)
        if ctrl and keyval == Gdk.KEY_space:
            button.emit("clicked")
            return True
        return False
    
    key_controller.connect("key-pressed", on_key_press, button, mic_combo)

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