#!/bin/bash

# wp_config_check.sh - Pull wp-config.php from SSM Parameter Store
# This script runs every 5 minutes via cron to update wp-config.php

# Configuration
REGION="${AWS_REGION:-us-east-1}"
WP_CONFIG_PATH="/var/www/html/wp-config.php"
SSM_PARAM_NAME="/clixx/wp-config-content"
LOG_FILE="/var/log/wp_config_check.log"
BACKUP_PATH="/var/www/html/wp-config.php.backup"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to assume cross-account role for SSM access
assume_role() {
    # Assume the TerraformSSMRole in Management account
    CREDS=$(aws sts assume-role \
        --role-arn "arn:aws:iam::135576900189:role/TerraformSSMRole" \
        --role-session-name "wp-config-update-$(date +%s)" \
        --region "$REGION" \
        --output json 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_message "ERROR: Failed to assume role for SSM access"
        return 1
    fi
    
    # Export temporary credentials
    export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')
    
    return 0
}

# Main execution
main() {
    log_message "Starting wp-config update check..."
    
    # Assume role for cross-account SSM access
    if ! assume_role; then
        log_message "ERROR: Could not assume role - exiting"
        exit 1
    fi
    
    # Get wp-config content from SSM Parameter Store
    NEW_CONFIG=$(aws ssm get-parameter \
        --name "$SSM_PARAM_NAME" \
        --with-decryption \
        --region "$REGION" \
        --query 'Parameter.Value' \
        --output text 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$NEW_CONFIG" ]; then
        log_message "ERROR: Failed to retrieve wp-config from SSM Parameter Store"
        # Clean up temporary credentials
        unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
        exit 1
    fi
    
    # Clean up temporary credentials
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
    
    # Check if current wp-config exists and get its content
    if [ -f "$WP_CONFIG_PATH" ]; then
        CURRENT_CONFIG=$(cat "$WP_CONFIG_PATH")
        
        # Compare configurations
        if [ "$CURRENT_CONFIG" = "$NEW_CONFIG" ]; then
            log_message "wp-config.php is already up to date"
            exit 0
        fi
        
        # Backup current config
        cp "$WP_CONFIG_PATH" "$BACKUP_PATH"
        log_message "Backed up current wp-config.php"
    fi
    
    # Write new configuration
    echo "$NEW_CONFIG" > "$WP_CONFIG_PATH"
    
    if [ $? -eq 0 ]; then
        # Set proper permissions
        chown apache:apache "$WP_CONFIG_PATH"
        chmod 640 "$WP_CONFIG_PATH"
        log_message "Successfully updated wp-config.php from SSM Parameter Store"
        
        # Restart Apache to pick up changes
        systemctl reload httpd 2>/dev/null || log_message "WARNING: Could not reload Apache"
    else
        log_message "ERROR: Failed to write new wp-config.php"
        # Restore backup if it exists
        if [ -f "$BACKUP_PATH" ]; then
            cp "$BACKUP_PATH" "$WP_CONFIG_PATH"
            log_message "Restored previous wp-config.php from backup"
        fi
        exit 1
    fi
}

# Run main function
main "$@"
