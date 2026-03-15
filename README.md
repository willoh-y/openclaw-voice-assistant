# OpenClaw Voice Assistant

**Vibe Coded** - The code is probably pretty bad

A voice-activated assistant for [OpenClaw](https://github.com/chand1012/openclaw) that lets you have natural voice conversations with your AI assistant. Built for Linux with NixOS integration.

## Features

- 🎤 **Voice-to-Text**: Supports both Deepgram (cloud) and Whisper (local) for speech recognition
- 🗣️ **Text-to-Speech**: Choose between ElevenLabs (high quality) or Edge TTS (free, offline)
- 🔄 **Smart Interrupts**: Interrupt the assistant mid-response by speaking
- 💤 **Dormant Mode**: Toggle listening on/off with a signal (perfect for hotkey binding)
- 🎨 **Visual Feedback**: Minimal Quickshell overlay shows current state
- 🔇 **Noise Gating**: Built-in audio filtering to ignore background noise
- 📦 **NixOS Native**: First-class Nix flake support with systemd service

## Demo

The assistant operates in different states with visual feedback:

- **Dormant** 💤 - Service running but not listening (invisible)
- **Idle** ⭕ - Waiting for speech
- **Listening** 🎤 - Actively recording your voice
- **Thinking** 💭 - Processing with OpenClaw
- **Speaking** 🔊 - Playing back the response
- **Error** ❌ - Something went wrong

## Installation

### Prerequisites

- Linux with PipeWire audio
- [Quickshell](https://github.com/outfoxxed/quickshell) for UI overlay
- NixOS (recommended) or Nix package manager

### NixOS Installation

1. **Add the flake to your configuration**:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    openclaw-voice-assistant.url = "github:willoh-y/openclaw-voice-assistant";
  };

  outputs = { self, nixpkgs, openclaw-voice-assistant, ... }: {
    nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
      modules = [
        ./configuration.nix
        openclaw-voice-assistant.nixosModules.default
      ];
      specialArgs = {
        inherit openclaw-voice-assistant;
      };
    };
  };
}
```

2. **Enable the service in your configuration**:

```nix
# configuration.nix
{ config, openclaw-voice-assistant, ... }:
{
  imports = [
    openclaw-voice-assistant.nixosModules.default
  ];

  services.openclaw-voice-assistant = {
    enable = true;
    user = "yourusername";
    environmentFile = "/home/yourusername/.config/openclaw-voice-assistant/.env";
    configFile = "/home/yourusername/.config/openclaw-voice-assistant/config.yaml";
  };
}
```

3. **Set up your configuration files**:

```bash
mkdir -p ~/.config/openclaw-voice-assistant
cd ~/.config/openclaw-voice-assistant

# Copy example files
cp /nix/store/*/share/openclaw-voice-assistant/.env.example .env
cp /nix/store/*/share/openclaw-voice-assistant/config.yaml.example config.yaml

# Edit with your API keys and settings
$EDITOR .env
$EDITOR config.yaml
```

4. **Rebuild your system**:

```bash
sudo nixos-rebuild switch --flake .#yourhostname
```

### Standalone Nix Installation

```bash
# Clone the repository
git clone https://github.com/willoh-y/openclaw-voice-assistant.git
cd openclaw-voice-assistant

# Enter development shell
nix develop

# Copy and configure
cp .env.example .env
cp config.yaml config.yaml
$EDITOR .env
$EDITOR config.yaml

# Run directly
./openclaw_voice_assistant.py
```

## Configuration

### Environment Variables (.env)

```bash
# Speech-to-Text (choose one provider)
STT_API_KEY=your_deepgram_api_key  # For Deepgram provider

# Text-to-Speech (optional - only if using ElevenLabs)
TTS_API_KEY=your_elevenlabs_api_key

# OpenClaw API token
OPENCLAW_TOKEN=your_openclaw_token
```

### Configuration File (config.yaml)

```yaml
# Audio settings
audio:
  sample_rate: 16000
  channels: 1
  mic_device: ""  # Auto-select, or specify PipeWire device
  gate_threshold: 200  # Noise gate RMS threshold

# Speech-to-Text
stt:
  provider: "deepgram"  # or "whisper" for local
  model: "nova-3"
  language: "en"
  endpointing_ms: 1500  # Silence duration before stopping
  
  # Local Whisper settings (if provider: "whisper")
  whisper:
    url: "http://127.0.0.1:8178"
    inference_path: "/inference"
  
  # Voice Activity Detection for local processing
  vad:
    aggressiveness: 2  # 0-3, higher = more aggressive
    frame_ms: 30
    pre_speech_ms: 300
    min_speech_ms: 200

# Text-to-Speech
tts:
  provider: "elevenlabs"  # or "edge" for free offline TTS
  
  elevenlabs:
    voice_id: "lLgB6ZeIe84FSJa9pO1a"
    model: "eleven_flash_v2_5"
    stability: 0.5
    similarity_boost: 0.75
  
  edge:
    voice: "en-US-ChristopherNeural"

# OpenClaw LLM
llm:
  url: "http://127.0.0.1:18789"
  session_id: "agent:main:main"
  timeout_seconds: 120

# Interrupt detection
interrupt:
  delay_seconds: 0.5  # Wait before listening for interrupts
  sustained_threshold_seconds: 0.3  # Speech duration needed to interrupt
```

## Usage

### Starting the Service

**With systemd (NixOS)**:
```bash
# Service starts automatically on login, or manually:
systemctl --user start openclaw-voice-assistant

# Check status
systemctl --user status openclaw-voice-assistant

# View logs
journalctl --user -u openclaw-voice-assistant -f
```

**Standalone**:
```bash
./openclaw_voice_assistant.py
# Or specify custom paths:
./openclaw_voice_assistant.py --config /path/to/config.yaml --env-file /path/to/.env
```

### Toggling Active/Dormant Mode

The service starts in dormant mode (not listening). Toggle it with SIGUSR1:

```bash
# With systemd
systemctl --user kill --kill-whom=main -s SIGUSR1 openclaw-voice-assistant

# Or find the PID
pkill -USR1 -f openclaw_voice_assistant.py
```

**Pro tip**: Bind this to a hotkey in your window manager! Example for Hyprland:

```conf
# hyprland.conf
bind = SUPER, V, exec, systemctl --user kill --kill-whom=main -s SIGUSR1 openclaw-voice-assistant
```

### Workflow

1. **Activate** - Press your hotkey to start listening (overlay appears)
2. **Speak** - Talk naturally, the assistant detects speech automatically
3. **Wait** - After you stop talking, it processes and responds
4. **Interrupt** - Speak again during the response to interrupt
5. **Deactivate** - Press hotkey again to go dormant (overlay disappears)

## Architecture

```
┌─────────────┐
│   SIGUSR1   │ (User toggles active/dormant)
└──────┬──────┘
       ▼
┌─────────────────────────────────┐
│  OpenClaw Voice Assistant       │
│  ┌───────────────────────────┐  │
│  │  Audio Pipeline           │  │
│  │  (PipeWire → pw-record)   │  │
│  └───────────┬───────────────┘  │
│              ▼                   │
│  ┌───────────────────────────┐  │
│  │  Speech-to-Text           │  │
│  │  • Deepgram (streaming)   │  │
│  │  • Whisper (local VAD)    │  │
│  └───────────┬───────────────┘  │
│              ▼                   │
│  ┌───────────────────────────┐  │
│  │  OpenClaw LLM             │  │
│  │  (OpenAI-compatible API)  │  │
│  └───────────┬───────────────┘  │
│              ▼                   │
│  ┌───────────────────────────┐  │
│  │  Text-to-Speech           │  │
│  │  • ElevenLabs (streaming) │  │
│  │  • Edge TTS (offline)     │  │
│  └───────────┬───────────────┘  │
│              ▼                   │
│  ┌───────────────────────────┐  │
│  │  Audio Playback           │  │
│  │  (pw-play / ffplay)       │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────┐
│  Quickshell UI Overlay          │
│  (Reads state from file)        │
└─────────────────────────────────┘
```

## Development

```bash
# Enter development environment
nix develop

# Run with development mode (uses local files)
export OPENCLAW_VOICE_ASSISTANT_DEV=1
./openclaw_voice_assistant.py

# Or use the Nix shell which sets this automatically
```

The development environment includes:
- Python 3.12 with all dependencies
- PipeWire, ffmpeg, Quickshell
- Auto-configured to use local files

## Troubleshooting

### No audio detected
- Check PipeWire is running: `systemctl --user status pipewire`
- List audio devices: `pw-cli list-objects | grep node.name`
- Adjust `gate_threshold` in config.yaml (lower = more sensitive)

### Deepgram errors
- Verify API key in .env file
- Check network connectivity
- Try the Whisper provider as fallback

### Whisper server not responding
- Make sure whisper-server is running: `whisper-server -m /path/to/model.bin`
- Check URL in config.yaml matches server address
- NixOS users: Enable the whisper-server systemd service

### Service won't start
- Check logs: `journalctl --user -u openclaw-voice-assistant -f`
- Verify paths in service configuration
- Ensure .env file has correct permissions (not world-readable)

### Quickshell overlay not showing
- Verify Quickshell is installed: `which quickshell`
- Check state file exists: `ls $XDG_RUNTIME_DIR/openclaw-voice-assistant/state.txt`
- Look for Quickshell errors in logs

## Secret Management

For production NixOS deployments, use encrypted secrets:

**With agenix**:
```nix
services.openclaw-voice-assistant = {
  enable = true;
  user = "yourusername";
  environmentFile = config.age.secrets.openclaw-voice-assistant.path;
};
```

**With sops-nix**:
```nix
services.openclaw-voice-assistant = {
  enable = true;
  user = "yourusername";
  environmentFile = config.sops.secrets.openclaw-voice-assistant.path;
};
```

## License

MIT
