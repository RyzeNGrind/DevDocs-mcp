{
  description = "DevDocs MCP Server for Cloudflare Workers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs_20
            nodePackages.wrangler
            nodePackages.typescript
          ];

          shellHook = ''
            echo "DevDocs MCP Server Development Environment"
            echo "Use 'npx wrangler' to access Wrangler in this shell"
          '';
        };
      }
    );
}