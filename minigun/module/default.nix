# MiniGun - Account Rotation for Cloudflare Free Tier Usage
{ config, lib, pkgs, ... }:

let
  cfg = config.services.minigun;
in {
  options.services.minigun = with lib; {
    enable = mkEnableOption "Enable MiniGun account rotation service";

    accounts = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          email = mkOption {
            type = types.str;
            description = "Cloudflare account email";
          };
          apiKey = mkOption {
            type = types.str;
            description = "Cloudflare API key";
          };
          apiToken = mkOption {
            type = types.str;
            description = "Cloudflare API token";
          };
          accountId = mkOption {
            type = types.str;
            description = "Cloudflare account ID";
          };
          usageWeight = mkOption {
            type = types.int;
            default = 1;
            description = "Weight for account usage (higher = more usage)";
          };
          tags = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Tags to categorize accounts";
          };
        };
      });
      default = {};
      description = "Cloudflare accounts to rotate between";
    };

    secretsMethod = mkOption {
      type = types.enum [ "agenix" "sops" "1password" "plain" ];
      default = "plain";
      description = "Method to store and retrieve account secrets";
    };

    rotationStrategy = mkOption {
      type = types.enum [ "round-robin" "weighted" "least-used" ];
      default = "weighted";
      description = "Strategy for rotating between accounts";
    };

    statePath = mkOption {
      type = types.path;
      default = "/var/lib/minigun";
      description = "Path to store account usage state";
    };

    interval = mkOption {
      type = types.str;
      default = "1h";
      description = "Interval for checking usage limits and rotating accounts";
    };

    deployServices = mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Service name";
          };
          deployScript = mkOption {
            type = types.path;
            description = "Path to deployment script that accepts account credentials";
          };
          accountTags = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Only use accounts with these tags";
          };
        };
      });
      default = [];
      description = "Services to deploy across accounts";
    };
  };

  config = lib.mkIf cfg.enable {
    # Secret management based on chosen method
    sops.secrets = lib.mkIf (cfg.secretsMethod == "sops") 
      (lib.mapAttrs' (name: account: {
        name = "minigun-${name}";
        value = { };
      }) cfg.accounts);
    
    age.secrets = lib.mkIf (cfg.secretsMethod == "agenix")
      (lib.mapAttrs' (name: account: {
        name = "minigun-${name}";
        file = ./secrets/minigun-${name}.age;
      }) cfg.accounts);

    # Create the state directory
    systemd.tmpfiles.rules = [
      "d ${cfg.statePath} 0700 minigun minigun - -"
    ];

    # Create the user
    users.users.minigun = {
      isSystemUser = true;
      group = "minigun";
      home = cfg.statePath;
      createHome = true;
    };
    users.groups.minigun = {};

    # All systemd services combined
    systemd.services = lib.mkMerge [
      # Main rotation service
      {
        "minigun-rotation" = {
          description = "MiniGun Account Rotation Service";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          startAt = cfg.interval;
          serviceConfig = {
            Type = "oneshot";
            User = "minigun";
            Group = "minigun";
            WorkingDirectory = cfg.statePath;
            ExecStart = pkgs.writeShellScript "minigun-rotate" ''
              #!/usr/bin/env bash
              set -euo pipefail

              STATE_FILE="${cfg.statePath}/account-state.json"
              CURRENT_ACCOUNT_FILE="${cfg.statePath}/current-account.json"

              # Initialize state file if it doesn't exist
              if [ ! -f "$STATE_FILE" ]; then
                echo '{}' > "$STATE_FILE"
              fi

              # Load accounts and their usage information
              ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: account: ''
                # Account: ${name}
                if ! jq -e '.["${name}"]' "$STATE_FILE" > /dev/null 2>&1; then
                  # Initialize account state if not present
                  jq --arg name "${name}" '.[$name] = {
                    "usageCount": 0,
                    "lastUsed": null,
                    "currentUsage": {
                      "requests": 0,
                      "compute": 0,
                      "storage": 0
                    }
                  }' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
                fi
              '') cfg.accounts)}

              # Get account usage from Cloudflare API
              ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: account: ''
                # Update usage for ${name}
                echo "Checking usage for account: ${name}..."
                
                # Get API credentials based on secret method
                ${if cfg.secretsMethod == "plain" then ''
                  CF_EMAIL="${account.email}"
                  CF_API_KEY="${account.apiKey}"
                  CF_API_TOKEN="${account.apiToken}"
                  CF_ACCOUNT_ID="${account.accountId}"
                '' else if cfg.secretsMethod == "sops" then ''
                  CF_EMAIL=$(${pkgs.sops}/bin/sops -d "${config.sops.secrets."minigun-${name}".path}" | jq -r '.email')
                  CF_API_KEY=$(${pkgs.sops}/bin/sops -d "${config.sops.secrets."minigun-${name}".path}" | jq -r '.apiKey')
                  CF_API_TOKEN=$(${pkgs.sops}/bin/sops -d "${config.sops.secrets."minigun-${name}".path}" | jq -r '.apiToken')
                  CF_ACCOUNT_ID=$(${pkgs.sops}/bin/sops -d "${config.sops.secrets."minigun-${name}".path}" | jq -r '.accountId')
                '' else if cfg.secretsMethod == "agenix" then ''
                  CF_EMAIL=$(cat "${config.age.secrets."minigun-${name}".path}" | jq -r '.email')
                  CF_API_KEY=$(cat "${config.age.secrets."minigun-${name}".path}" | jq -r '.apiKey')
                  CF_API_TOKEN=$(cat "${config.age.secrets."minigun-${name}".path}" | jq -r '.apiToken')
                  CF_ACCOUNT_ID=$(cat "${config.age.secrets."minigun-${name}".path}" | jq -r '.accountId')
                '' else ''
                  # 1Password CLI
                  CF_DATA=$(${pkgs._1password}/bin/op item get "Cloudflare-${name}" --format=json)
                  CF_EMAIL=$(echo "$CF_DATA" | jq -r '.fields[] | select(.label=="email") | .value')
                  CF_API_KEY=$(echo "$CF_DATA" | jq -r '.fields[] | select(.label=="apiKey") | .value')
                  CF_API_TOKEN=$(echo "$CF_DATA" | jq -r '.fields[] | select(.label=="apiToken") | .value')
                  CF_ACCOUNT_ID=$(echo "$CF_DATA" | jq -r '.fields[] | select(.label=="accountId") | .value')
                ''}
                
                # Query Cloudflare API for current usage
                USAGE_DATA=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/workers/usage" \
                  -H "X-Auth-Email: $CF_EMAIL" \
                  -H "X-Auth-Key: $CF_API_KEY" \
                  -H "Authorization: Bearer $CF_API_TOKEN" \
                  -H "Content-Type: application/json")
                
                # Parse and update usage in state file
                if echo "$USAGE_DATA" | jq -e '.success == true' > /dev/null; then
                  REQUESTS=$(echo "$USAGE_DATA" | jq -r '.result.usage.requests' || echo "0")
                  COMPUTE=$(echo "$USAGE_DATA" | jq -r '.result.usage.duration' || echo "0")
                  
                  # Update state
                  jq --arg name "${name}" \
                     --arg requests "$REQUESTS" \
                     --arg compute "$COMPUTE" \
                     --arg now "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
                  '.[$name].currentUsage.requests = ($requests | tonumber) | 
                   .[$name].currentUsage.compute = ($compute | tonumber) | 
                   .[$name].lastChecked = $now' \
                  "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
                else
                  echo "Failed to get usage for ${name}: $(echo "$USAGE_DATA" | jq -r '.errors[0].message')"
                fi
              '') cfg.accounts)}

              # Select next account based on rotation strategy
              echo "Selecting next account using ${cfg.rotationStrategy} strategy..."
              
              case "${cfg.rotationStrategy}" in
                "round-robin")
                  # Simply get the least recently used account
                  NEXT_ACCOUNT=$(jq -r 'to_entries | sort_by(.value.lastUsed) | .[0].key' "$STATE_FILE")
                  ;;
                  
                "weighted")
                  # Use weighted random selection based on usageWeight
                  TOTAL_WEIGHT=$((${lib.sum (lib.mapAttrsToList (name: account: account.usageWeight) cfg.accounts)}))
                  RANDOM_WEIGHT=$((RANDOM % TOTAL_WEIGHT + 1))
                  
                  CURRENT_WEIGHT=0
                  ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: account: ''
                    if [ -z "$NEXT_ACCOUNT" ]; then
                      CURRENT_WEIGHT=$((CURRENT_WEIGHT + ${toString account.usageWeight}))
                      if [ $CURRENT_WEIGHT -ge $RANDOM_WEIGHT ]; then
                        NEXT_ACCOUNT="${name}"
                      fi
                    fi
                  '') cfg.accounts)}
                  ;;
                  
                "least-used")
                  # Get account with lowest current usage percentage
                  ${lib.concatMapStrings (name: account: ''
                    # Calculate usage percentage for ${name}
                    REQUESTS=$(jq -r '.["${name}"].currentUsage.requests' "$STATE_FILE")
                    USAGE_PCT=$((REQUESTS * 100 / 100000)) # 100k is daily limit
                    
                    jq --arg name "${name}" --arg pct "$USAGE_PCT" \
                       '.[$name].usagePct = ($pct | tonumber)' \
                       "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
                  '') (lib.attrNames cfg.accounts)}
                  
                  # Select account with lowest usage
                  NEXT_ACCOUNT=$(jq -r 'to_entries | sort_by(.value.usagePct) | .[0].key' "$STATE_FILE")
                  ;;
              esac
              
              echo "Selected account: $NEXT_ACCOUNT"
              
              # Update usage count and timestamp for selected account
              jq --arg name "$NEXT_ACCOUNT" --arg now "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
                 '.[$name].usageCount = (.[$name].usageCount // 0) + 1 | 
                  .[$name].lastUsed = $now' \
                 "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
              
              # Save current account
              jq --arg name "$NEXT_ACCOUNT" -n '{account: $name}' > "$CURRENT_ACCOUNT_FILE"
              
              # Execute deploy scripts for each service
              ${lib.concatMapStrings (service: ''
                echo "Deploying service: ${service.name}..."
                
                # Filter accounts by tags if specified
                ${if service.accountTags != [] then ''
                  # Find accounts matching the required tags
                  MATCHING_ACCOUNTS=""
                  ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: account: 
                    if lib.any (tag: lib.elem tag service.accountTags) account.tags
                    then ''MATCHING_ACCOUNTS="$MATCHING_ACCOUNTS ${name}"''
                    else ""
                  ) cfg.accounts)}
                  
                  if [ -z "$MATCHING_ACCOUNTS" ]; then
                    echo "No accounts match tags for service ${service.name}, using current account"
                    SERVICE_ACCOUNT="$NEXT_ACCOUNT"
                  else
                    # Pick one of the matching accounts
                    SERVICE_ACCOUNT=$(echo "$MATCHING_ACCOUNTS" | tr ' ' '\n' | sort -R | head -n1)
                  fi
                '' else ''
                  # Use the current account
                  SERVICE_ACCOUNT="$NEXT_ACCOUNT"
                ''}
                
                # Get credentials for the service account
                ${if cfg.secretsMethod == "plain" then ''
                  CF_EMAIL="${lib.getAttr "SERVICE_ACCOUNT" cfg.accounts}.email"
                  CF_API_KEY="${lib.getAttr "SERVICE_ACCOUNT" cfg.accounts}.apiKey"
                  CF_API_TOKEN="${lib.getAttr "SERVICE_ACCOUNT" cfg.accounts}.apiToken"
                  CF_ACCOUNT_ID="${lib.getAttr "SERVICE_ACCOUNT" cfg.accounts}.accountId"
                '' else if cfg.secretsMethod == "sops" then ''
                  CF_EMAIL=$(${pkgs.sops}/bin/sops -d "${config.sops.secrets."minigun-$SERVICE_ACCOUNT".path}" | jq -r '.email')
                  CF_API_KEY=$(${pkgs.sops}/bin/sops -d "${config.sops.secrets."minigun-$SERVICE_ACCOUNT".path}" | jq -r '.apiKey')
                  CF_API_TOKEN=$(${pkgs.sops}/bin/sops -d "${config.sops.secrets."minigun-$SERVICE_ACCOUNT".path}" | jq -r '.apiToken')
                  CF_ACCOUNT_ID=$(${pkgs.sops}/bin/sops -d "${config.sops.secrets."minigun-$SERVICE_ACCOUNT".path}" | jq -r '.accountId')
                '' else if cfg.secretsMethod == "agenix" then ''
                  CF_EMAIL=$(cat "${config.age.secrets."minigun-$SERVICE_ACCOUNT".path}" | jq -r '.email')
                  CF_API_KEY=$(cat "${config.age.secrets."minigun-$SERVICE_ACCOUNT".path}" | jq -r '.apiKey')
                  CF_API_TOKEN=$(cat "${config.age.secrets."minigun-$SERVICE_ACCOUNT".path}" | jq -r '.apiToken')
                  CF_ACCOUNT_ID=$(cat "${config.age.secrets."minigun-$SERVICE_ACCOUNT".path}" | jq -r '.accountId')
                '' else ''
                  # 1Password CLI
                  CF_DATA=$(${pkgs._1password}/bin/op item get "Cloudflare-$SERVICE_ACCOUNT" --format=json)
                  CF_EMAIL=$(echo "$CF_DATA" | jq -r '.fields[] | select(.label=="email") | .value')
                  CF_API_KEY=$(echo "$CF_DATA" | jq -r '.fields[] | select(.label=="apiKey") | .value')
                  CF_API_TOKEN=$(echo "$CF_DATA" | jq -r '.fields[] | select(.label=="apiToken") | .value')
                  CF_ACCOUNT_ID=$(echo "$CF_DATA" | jq -r '.fields[] | select(.label=="accountId") | .value')
                ''}
                
                # Run the deployment script with credentials
                CF_EMAIL="$CF_EMAIL" \
                CF_API_KEY="$CF_API_KEY" \
                CF_API_TOKEN="$CF_API_TOKEN" \
                CF_ACCOUNT_ID="$CF_ACCOUNT_ID" \
                ACCOUNT_NAME="$SERVICE_ACCOUNT" \
                ${service.deployScript}
              '') cfg.deployServices}
              
              echo "Account rotation completed successfully"
            '';
          };
        }
      }

      # Individual deployment services
      (lib.mkMerge (map (service: {
        "minigun-deploy-${service.name}" = {
          description = "MiniGun Deployment for ${service.name}";
          after = [ "network.target" ];
          serviceConfig = {
            Type = "oneshot";
            User = "minigun";
            Group = "minigun";
            WorkingDirectory = cfg.statePath;
            ExecStart = pkgs.writeShellScript "minigun-deploy-${service.name}" ''
              #!/usr/bin/env bash
              set -euo pipefail

              if [ ! -f "${cfg.statePath}/current-account.json" ]; then
                echo "No account currently selected"
                exit 1
              fi
              
              ACCOUNT=$(jq -r '.account' "${cfg.statePath}/current-account.json")
              echo "Using account: $ACCOUNT"
              
              # Get credentials for the account
              ${if cfg.secretsMethod == "plain" then ''
                CF_EMAIL="${lib.getAttr "ACCOUNT" cfg.accounts}.email"
                CF_API_KEY="${lib.getAttr "ACCOUNT" cfg.accounts}.apiKey"
                CF_API_TOKEN="${lib.getAttr "ACCOUNT" cfg.accounts}.apiToken"
                CF_ACCOUNT_ID="${lib.getAttr "ACCOUNT" cfg.accounts}.accountId"
              '' else if cfg.secretsMethod == "sops" then ''
                CF_EMAIL=$(${pkgs.sops}/bin/sops -d "${config.sops.secrets."minigun-$ACCOUNT".path}" | jq -r '.email')
                CF_API_KEY=$(${pkgs.sops}/bin/sops -d "${config.sops.secrets."minigun-$ACCOUNT".path}" | jq -r '.apiKey')
                CF_API_TOKEN=$(${pkgs.sops}/bin/sops -d "${config.sops.secrets."minigun-$ACCOUNT".path}" | jq -r '.apiToken')
                CF_ACCOUNT_ID=$(${pkgs.sops}/bin/sops -d "${config.sops.secrets."minigun-$ACCOUNT".path}" | jq -r '.accountId')
              '' else if cfg.secretsMethod == "agenix" then ''
                CF_EMAIL=$(cat "${config.age.secrets."minigun-$ACCOUNT".path}" | jq -r '.email')
                CF_API_KEY=$(cat "${config.age.secrets."minigun-$ACCOUNT".path}" | jq -r '.apiKey')
                CF_API_TOKEN=$(cat "${config.age.secrets."minigun-$ACCOUNT".path}" | jq -r '.apiToken')
                CF_ACCOUNT_ID=$(cat "${config.age.secrets."minigun-$ACCOUNT".path}" | jq -r '.accountId')
              '' else ''
                # 1Password CLI
                CF_DATA=$(${pkgs._1password}/bin/op item get "Cloudflare-$ACCOUNT" --format=json)
                CF_EMAIL=$(echo "$CF_DATA" | jq -r '.fields[] | select(.label=="email") | .value')
                CF_API_KEY=$(echo "$CF_DATA" | jq -r '.fields[] | select(.label=="apiKey") | .value')
                CF_API_TOKEN=$(echo "$CF_DATA" | jq -r '.fields[] | select(.label=="apiToken") | .value')
                CF_ACCOUNT_ID=$(echo "$CF_DATA" | jq -r '.fields[] | select(.label=="accountId") | .value')
              ''}
              
              # Run the deployment script with credentials
              CF_EMAIL="$CF_EMAIL" \
              CF_API_KEY="$CF_API_KEY" \
              CF_API_TOKEN="$CF_API_TOKEN" \
              CF_ACCOUNT_ID="$CF_ACCOUNT_ID" \
              ACCOUNT_NAME="$ACCOUNT" \
              ${service.deployScript}
            '';
          };
        };
      }) cfg.deployServices))
    ];

    # Helper scripts for the module
    environment.systemPackages = [ 
      (pkgs.writeShellScriptBin "minigun-current-account" ''
        #!/usr/bin/env bash
        if [ ! -f "${cfg.statePath}/current-account.json" ]; then
          echo "No account currently selected"
          exit 1
        fi
        
        ACCOUNT=$(jq -r '.account' "${cfg.statePath}/current-account.json")
        echo "Current account: $ACCOUNT"
        
        if [ -f "${cfg.statePath}/account-state.json" ]; then
          jq ".[$ACCOUNT]" "${cfg.statePath}/account-state.json"
        fi
      '')
      
      (pkgs.writeShellScriptBin "minigun-list-accounts" ''
        #!/usr/bin/env bash
        if [ ! -f "${cfg.statePath}/account-state.json" ]; then
          echo "No account state available"
          exit 1
        fi
        
        jq '.' "${cfg.statePath}/account-state.json"
      '')
      
      (pkgs.writeShellScriptBin "minigun-deploy" ''
        #!/usr/bin/env bash
        if [ $# -lt 1 ]; then
          echo "Usage: minigun-deploy <service-name>"
          echo "Available services:"
          ${lib.concatMapStrings (service: ''
            echo "  ${service.name}"
          '') cfg.deployServices}
          exit 1
        fi
        
        SERVICE="$1"
        FOUND=0
        
        ${lib.concatMapStrings (service: ''
          if [ "$SERVICE" = "${service.name}" ]; then
            FOUND=1
            echo "Manually deploying service: ${service.name}..."
            systemctl start "minigun-deploy-${service.name}.service"
          fi
        '') cfg.deployServices}
        
        if [ $FOUND -eq 0 ]; then
          echo "Service not found: $SERVICE"
          echo "Available services:"
          ${lib.concatMapStrings (service: ''
            echo "  ${service.name}"
          '') cfg.deployServices}
          exit 1
        fi
      '')
    ];
  };
} 