{
  description = "OpenClaw Voice - Voice chat with OpenClaw";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        python = pkgs.python312;
        pythonPackages = python.pkgs;

        # Runtime dependencies needed for the application
        runtimeDeps = with pkgs; [
          pipewire # pw-record, pw-play
          ffmpeg # ffplay (for Edge TTS)
          quickshell # UI overlay
        ];

        # Build the main application package
        openclaw-voice-assistant = pkgs.stdenv.mkDerivation {
          pname = "openclaw-voice-assistant";
          version = "0.1.0";

          src = ./.;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          buildInputs = [
            (python.withPackages (
              ps: with ps; [
                numpy
                websockets
                aiohttp
                python-dotenv
                edge-tts
                pyyaml
                webrtcvad
                setuptools
              ]
            ))
          ];

          # No build step needed
          dontBuild = true;

          installPhase = ''
            runHook preInstall

            # Install Python modules
            mkdir -p $out/lib/openclaw-voice-assistant
            cp openclaw_voice_assistant.py $out/lib/openclaw-voice-assistant/
            cp config.py $out/lib/openclaw-voice-assistant/

            # Install QML UI file
            mkdir -p $out/share/openclaw-voice-assistant
            cp shell.qml $out/share/openclaw-voice-assistant/

            # Install example config and env files
            cp config.yaml $out/share/openclaw-voice-assistant/config.yaml.example
            cp .env.example $out/share/openclaw-voice-assistant/

            # Create wrapper script
            mkdir -p $out/bin
            makeWrapper ${
              python.withPackages (
                ps: with ps; [
                  numpy
                  websockets
                  aiohttp
                  python-dotenv
                  edge-tts
                  pyyaml
                  webrtcvad
                  setuptools
                ]
              )
            }/bin/python $out/bin/openclaw-voice-assistant \
              --add-flags "$out/lib/openclaw-voice-assistant/openclaw_voice_assistant.py" \
              --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps} \
              --set OPENCLAW_VOICE_ASSISTANT_QML_PATH "$out/share/openclaw-voice-assistant/shell.qml"

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Voice chat interface for OpenClaw";
            license = licenses.mit;
            platforms = platforms.linux;
            mainProgram = "openclaw-voice-assistant";
          };
        };

      in
      {
        # Main package
        packages = {
          default = openclaw-voice-assistant;
          openclaw-voice-assistant = openclaw-voice-assistant;
        };

        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = runtimeDeps ++ [
            (python.withPackages (
              ps: with ps; [
                numpy
                websockets
                aiohttp
                python-dotenv
                edge-tts
                pyyaml
                webrtcvad
                setuptools
              ]
            ))
          ];

          shellHook = ''
            echo "OpenClaw Voice Assistant development environment"
            echo ""
            echo "Run: ./openclaw_voice_assistant.py --help"
            echo ""
            echo "First time setup:"
            echo "  1. Copy .env.example to .env and fill in your API keys"
            echo "  2. Edit config.yaml to customize settings"
            echo ""
            echo "Or for production setup:"
            echo "  mkdir -p ~/.config/openclaw-voice-assistant"
            echo "  cp .env.example ~/.config/openclaw-voice-assistant/.env"
            echo "  cp config.yaml ~/.config/openclaw-voice-assistant/config.yaml"
            echo "  # Edit the files with your settings"
            echo ""

            # Set dev mode so local files are used
            export OPENCLAW_VOICE_ASSISTANT_DEV=1
          '';
        };
      }
    )
    // {
      # NixOS module (system-independent)
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        with lib;
        let
          cfg = config.services.openclaw-voice-assistant;
          # Get the package for the current system
          pkg = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        in
        {
          options.services.openclaw-voice-assistant = {
            enable = mkEnableOption "OpenClaw Voice Assistant service";

            package = mkOption {
              type = types.package;
              default = pkg;
              defaultText = literalExpression "pkgs.openclaw-voice-assistant";
              description = "The openclaw-voice-assistant package to use.";
            };

            user = mkOption {
              type = types.str;
              description = "User to run the service as.";
            };

            configFile = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = ''
                Path to config.yaml file.
                If null, will use ~/.config/openclaw-voice-assistant/config.yaml
              '';
            };

            environmentFile = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = ''
                Path to file containing environment variables (API keys).
                This file should contain lines like:
                  STT_API_KEY=your_key_here
                  TTS_API_KEY=your_key_here
                  OPENCLAW_TOKEN=your_token_here

                If null, the application will look for .env in the XDG config directory.

                For secret management with agenix:
                  services.openclaw-voice-assistant.environmentFile = config.age.secrets.openclaw-voice-assistant.path;

                For secret management with sops-nix:
                  services.openclaw-voice-assistant.environmentFile = config.sops.secrets.openclaw-voice-assistant.path;
              '';
            };
          };

          config = mkIf cfg.enable {
            # Add package to system packages
            environment.systemPackages = [ cfg.package ];

            # Create systemd user service
            systemd.user.services.open-claw-voice = {
              description = "OpenClaw Voice Assistant - Voice chat with OpenClaw";
              wantedBy = [ "default.target" ];
              after = [
                "pipewire.service"
                "pipewire-pulse.service"
              ];
              requires = [ "pipewire.service" ];

              serviceConfig = {
                Type = "simple";
                ExecStart =
                  let
                    args = lib.concatStringsSep " " (
                      [ "--no-log-file" ] ++ lib.optional (cfg.configFile != null) "--config ${cfg.configFile}"
                    );
                  in
                  "${cfg.package}/bin/openclaw-voice-assistant ${args}";

                Restart = "on-failure";
                RestartSec = "5s";

                # Allow SIGUSR1 for toggling active/dormant state
                # Users can run: systemctl --user kill --kill-whom=main -s SIGUSR1 openclaw-voice-assistant
                # Using KillMode=process so signals only go to main process by default
                KillMode = "process";
                KillSignal = "SIGTERM";
              }
              // lib.optionalAttrs (cfg.environmentFile != null) {
                EnvironmentFile = cfg.environmentFile;
              };

              # Environment file for API keys (if specified)
              environment = {
                # Ensure XDG directories are available
                XDG_RUNTIME_DIR = "/run/user/%U";
              };
            };
          };
        };
    };
}
