# Example configuration for using MiniGun with DevDocs
# Import this into your nixos configuration or use flakes
{
  imports = [
    # Import the MiniGun module from the flake
    (builtins.getFlake "github:your-username/DevDocs").nixosModules.minigun
    # Import the DevDocs module from the flake  
    (builtins.getFlake "github:your-username/DevDocs").nixosModules.devdocs
  ];

  # Enable DevDocs service
  services.devdocs = {
    enable = true;
    port = 24125;
    mcpPort = 8787;
    dataDir = "/var/lib/devdocs";
  };

  # Enable and configure MiniGun account rotation
  services.minigun = {
    enable = true;
    
    # Configure multiple Cloudflare accounts
    accounts = {
      # First account
      account1 = {
        email = "account1@example.com";
        apiKey = "placeholder-api-key-1";  # Use secretsMethod other than plain for production
        apiToken = "placeholder-api-token-1";
        accountId = "placeholder-account-id-1";
        usageWeight = 3;  # Higher weight means this account will be used more frequently
        tags = [ "dev" "mcp" ];
      };
      
      # Second account
      account2 = {
        email = "account2@example.com";
        apiKey = "placeholder-api-key-2";
        apiToken = "placeholder-api-token-2";
        accountId = "placeholder-account-id-2";
        usageWeight = 1;  # Lower weight means less frequent use
        tags = [ "prod" "mcp" ];
      };
      
      # Third account - for testing only
      account3 = {
        email = "account3@example.com";
        apiKey = "placeholder-api-key-3";
        apiToken = "placeholder-api-token-3";
        accountId = "placeholder-account-id-3";
        usageWeight = 1;
        tags = [ "test" ];
      };
    };
    
    # Use agenix for secure credentials storage
    # This improves security compared to plain text credentials
    secretsMethod = "agenix";
    
    # Use least-used strategy to maximize free tier utilization
    rotationStrategy = "least-used";
    
    # Check usage and rotate accounts every 30 minutes
    interval = "30m";
    
    # Configure deployment services
    deployServices = [
      {
        name = "devdocs-mcp";
        # Reference the deployment script from the flake
        deployScript = (builtins.getFlake "github:your-username/DevDocs").packages.${builtins.currentSystem}.deployDevDocsMcp;
        # Only use accounts with the "mcp" tag
        accountTags = [ "mcp" ];
      }
    ];
  };
  
  # If using agenix, configure age.secrets
  age.secrets = {
    "minigun-account1" = {
      file = ./secrets/minigun-account1.age;
      owner = "minigun";
      group = "minigun";
    };
    "minigun-account2" = {
      file = ./secrets/minigun-account2.age;
      owner = "minigun";
      group = "minigun";
    };
    "minigun-account3" = {
      file = ./secrets/minigun-account3.age;
      owner = "minigun";
      group = "minigun";
    };
  };
  
  # Add the minigun management scripts to the system path
  environment.systemPackages = with pkgs; [
    jq
    curl
  ];
  
  # Firewall configuration for DevDocs services
  networking.firewall.allowedTCPPorts = [ 24125 8787 3001 ];
} 