{
  description = "DevDocs Explorer - Documentation crawling and MCP integration";
  nixConfig = {
    extra-substituters = [
      "https://devdocs-mcp.cachix.org"
    ];
    extra-trusted-public-keys = [
      "devdocs-mcp.cachix.org-1:BDuKzDWQxySNasd+srtl1+TT3QRBSPtAzoQiAnX1b6w="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
    devshell.url = "github:numtide/devshell";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, systems, devshell, pre-commit-hooks, fenix, flake-utils, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;
      imports = [ devshell.flakeModule ];

      perSystem = { config, self', pkgs, system, lib, ... }: let
        nodejs = pkgs.nodejs_18;
        python = pkgs.python311;
        
        # Define Python packages without sphinx
        pythonEnv = python.withPackages (ps: with ps; [
          fastapi
          uvicorn
          requests
          psutil
          pydantic
          python-dotenv
          httpx
          nest-asyncio
          python-multipart
        ]);
        
        # Use standalone wrangler to avoid broken symlinks
        wranglerPackage = pkgs.mkYarnPackage {
          name = "wrangler-standalone";
          src = pkgs.fetchFromGitHub {
            owner = "cloudflare";
            repo = "workers-sdk";
            rev = "wrangler@3.19.0";
            hash = "sha256-Z9ImqIBT/OL8/t0Uhfq7Zs3Mx5IxEQzGnwVZB1xH2xU=";
          };
          packageJSON = ./package.json;
          yarnLock = ./yarn.lock;
          buildPhase = "yarn --offline build";
          fixupPhase = ''
            mkdir -p $out/bin
            ln -s $out/libexec/wrangler/bin/wrangler.js $out/bin/wrangler
            chmod +x $out/bin/wrangler
          '';
        };
      in {
        # Git pre-commit hooks
        checks = {
          pre-commit-check = pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              alejandra.enable = true;
              statix.enable = true;
              deadnix.enable = true;
              prettier = {
                enable = true;
                excludes = [ "*.nix" ];
              };
              eslint = {
                enable = true;
                excludes = [ "*.nix" ];
                files = "\\.ts$";
              };
            };
          };
        };
        
        # Development shells
        devshells.default = {
          name = "devdocs-dev";
          packages = with pkgs; [
            nodejs
            nodePackages.typescript
            nodePackages.typescript-language-server
            # Use nodejs's wrangler directly instead of the problematic package
            nodePackages.wrangler
            pythonEnv
            alejandra # Use alejandra instead of nixfmt-classic
            statix
            deadnix
            jq
            curl
            ripgrep
          ];

          env = [
            {
              name = "NODE_ENV";
              value = "development";
            }
            {
              name = "PYTHONPATH";
              value = "$PYTHONPATH:$PWD/backend";
            }
            {
              name = "NEXT_PUBLIC_BACKEND_URL";
              value = "http://localhost:24125";
            }
            {
              name = "PRE_COMMIT_ALLOW_NO_CONFIG";
              value = "1";
            }
          ];

          # Use git hooks from pre-commit-hooks
          devshell.startup.pre-commit-install.text = self'.checks.pre-commit-check.shellHook;

          commands = [
            {
              name = "setup";
              help = "Set up the DevDocs project with all dependencies";
              command = ''
                echo "Setting up DevDocs project..."
                # MCP Server setup
                (cd devdocs-mcp && npm install)
                # Backend setup
                (cd backend && ${pythonEnv.interpreter} -m pip install -r requirements.txt)
                echo "Setup complete!"
              '';
            }
            {
              name = "start-all";
              help = "Start all DevDocs services";
              command = ''
                echo "Starting all DevDocs services..."
                export NEXT_PUBLIC_BACKEND_URL=http://localhost:24125
                ./start.sh
              '';
            }
            {
              name = "start-mcp";
              help = "Start only the MCP server";
              command = ''
                echo "Starting MCP server..."
                (cd devdocs-mcp && npx wrangler dev)
              '';
            }
            {
              name = "start-backend";
              help = "Start only the backend service";
              command = ''
                echo "Starting backend service..."
                (cd backend && ${pythonEnv.interpreter} -m uvicorn app.main:app --host 0.0.0.0 --port 24125)
              '';
            }
            {
              name = "deploy-mcp";
              help = "Deploy the MCP server to Cloudflare Workers";
              command = ''
                echo "Deploying MCP server to Cloudflare Workers..."
                (cd devdocs-mcp && npx wrangler deploy)
              '';
            }
            {
              name = "test-mcp";
              help = "Test the MCP server with the official MCP Inspector";
              command = ''
                echo "Starting MCP Inspector to test your MCP server..."
                echo "First, start your MCP server in another terminal with 'start-mcp'"
                echo "Then connect to http://localhost:8787/sse in the inspector"
                npx @modelcontextprotocol/inspector@latest
              '';
            }
            {
              name = "fix-mcp-linting";
              help = "Fix linting issues in the MCP server";
              command = ''
                echo "Fixing linting issues in MCP server..."
                (cd devdocs-mcp && npx eslint --fix src/*)
              '';
            }
            {
              name = "format-nix";
              help = "Format Nix files with Alejandra";
              command = ''
                echo "Formatting Nix files..."
                alejandra .
              '';
            }
          ];
        };

        # Packages
        packages = {
          devdocs-mcp = pkgs.buildNpmPackage {
            name = "devdocs-mcp";
            version = "1.0.0";
            src = ./devdocs-mcp;
            npmDepsHash = "sha256-4GwJzoLOTv4NY7YiIWFoVYpBM/YdIr2/PF1KQT1/79E="; # Computed hash
            installPhase = ''
              mkdir -p $out
              cp -r dist $out/
              cp package.json $out/
            '';
            buildInputs = [ nodejs ];
          };

          devdocs-backend = pkgs.python311.pkgs.buildPythonApplication {
            name = "devdocs-backend";
            version = "1.0.0";
            src = ./backend;
            propagatedBuildInputs = with pkgs.python311.pkgs; [
              fastapi
              uvicorn
              requests
              psutil
              pydantic
              python-dotenv
              httpx
              nest-asyncio
              python-multipart
            ];
          };

          # Build the entire system as one package
          default = pkgs.symlinkJoin {
            name = "devdocs";
            paths = [ self'.packages.devdocs-mcp self'.packages.devdocs-backend ];
          };
        };

        # Apps to run with `nix run`
        apps = {
          mcp = flake-utils.lib.mkApp {
            drv = pkgs.writeShellApplication {
              name = "devdocs-mcp";
              runtimeInputs = [ nodejs ];
              text = ''
                cd ${self'.packages.devdocs-mcp}/
                export NEXT_PUBLIC_BACKEND_URL=''${NEXT_PUBLIC_BACKEND_URL:-http://localhost:24125}
                node dist/index.js
              '';
            };
          };

          backend = flake-utils.lib.mkApp {
            drv = pkgs.writeShellApplication {
              name = "devdocs-backend";
              runtimeInputs = [ pythonEnv ];
              text = ''
                cd ${self'.packages.devdocs-backend}/
                python -m uvicorn app.main:app --host 0.0.0.0 --port 24125
              '';
            };
          };

          test-mcp = flake-utils.lib.mkApp {
            drv = pkgs.writeShellApplication {
              name = "test-mcp";
              runtimeInputs = [ nodejs ];
              text = ''
                echo "Starting MCP Inspector to test your MCP server..."
                echo "Make sure your MCP server is running on http://localhost:8787/sse"
                npx @modelcontextprotocol/inspector@latest
              '';
            };
          };

          default = self'.apps.mcp;
        };
      };

      # Flake-wide configurations
      flake = {
        # NixOS module for system-level deployment
        nixosModules.devdocs = { config, lib, pkgs, ... }: {
          options = {
            services.devdocs = {
              enable = lib.mkEnableOption "Enable DevDocs service";
              port = lib.mkOption {
                type = lib.types.port;
                default = 24125;
                description = "Port to run the backend service on";
              };
              mcpPort = lib.mkOption {
                type = lib.types.port;
                default = 8787;
                description = "Port to run the MCP server on";
              };
              dataDir = lib.mkOption {
                type = lib.types.path;
                default = "/var/lib/devdocs";
                description = "Directory to store DevDocs data";
              };
              backendUrl = lib.mkOption {
                type = lib.types.str;
                default = "http://localhost:24125";
                description = "URL for the backend service";
              };
            };
          };

          config = lib.mkIf config.services.devdocs.enable {
            systemd.services.devdocs-backend = {
              description = "DevDocs Backend Service";
              wantedBy = [ "multi-user.target" ];
              after = [ "network.target" ];
              environment = {
                PORT = toString config.services.devdocs.port;
                STORAGE_PATH = "${config.services.devdocs.dataDir}/storage";
                MARKDOWN_DIR = "${config.services.devdocs.dataDir}/storage/markdown";
                NEXT_PUBLIC_BACKEND_URL = config.services.devdocs.backendUrl;
              };
              serviceConfig = {
                ExecStart = "${self.packages.${pkgs.system}.devdocs-backend}/bin/devdocs-backend";
                Restart = "always";
                User = "devdocs";
                Group = "devdocs";
                WorkingDirectory = "/var/lib/devdocs";
              };
            };

            # Create the devdocs user and group
            users.users.devdocs = {
              isSystemUser = true;
              group = "devdocs";
              home = "/var/lib/devdocs";
              createHome = true;
            };
            users.groups.devdocs = {};

            # Create required directories with proper permissions
            system.activationScripts.devdocs-dirs = lib.stringAfter [ "users" "groups" ] ''
              mkdir -p ${config.services.devdocs.dataDir}/{storage,logs,crawl_results}
              mkdir -p ${config.services.devdocs.dataDir}/storage/{markdown,html}
              chown -R devdocs:devdocs ${config.services.devdocs.dataDir}
            '';
          };
        };
      };
    };
}