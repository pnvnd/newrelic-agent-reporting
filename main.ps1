#!/usr/bin/env pwsh

param (
    [string]$feature,
    [string]$region = "US", # Default to US if no region is provided
    [switch]$Help
)

# Define API key and endpoint parameters
$apiKey = "NRAK-XXXXXXXXXXXXXXXXXXXXXXXXXXX"
$accountId = "1234567"

# Determine which region-specific API endpoint to use
switch ($region) {
    "US" {
        $apiEndpoint = "https://api.newrelic.com/graphql"
    }
    "EU" {
        $apiEndpoint = "https://api.eu.newrelic.com/graphql"
    }
    default {
        Write-Host "Invalid region. Please specify 'US' or 'EU' for the -Region parameter."
        return
    }
}

# Construct the script filename dynamically
$ScriptFilename = "./$feature.ps1"

# Check if the script file exists
if (Test-Path $ScriptFilename) {
    # Execute the script
    & $ScriptFilename -ApiKey $ApiKey -accountId $accountId -ApiEndpoint $ApiEndpoint
} else {
    Write-Host "Invalid feature name. Please specify a valid feature script without the file extension."
}

# Check if the -Help switch is provided
if ($Help) {
    Write-Host "Script usage:"
    Write-Host "  main.ps1 -feature <feature> -region <US|EU>"
    Write-Host "  Optional: -Help (Show this help message)"
    return
}