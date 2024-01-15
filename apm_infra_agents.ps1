#!/usr/bin/env pwsh

# Script version: 1.5 - apm and infra agent list results saved to a file

# ENTRY POINT MAIN()
Param(
    [Parameter(Mandatory=$True)]
    [String] $accountId,
    [Parameter(Mandatory=$True)]
    [String] $apiKey,
    [Parameter(Mandatory=$True)]
    [String] $apiEndpoint
)

# File paths for apm and infra results in the same directory as the script
$apmFilePath = Join-Path (Get-Location).path "apm_results.csv"
$infraFilePath = Join-Path (Get-Location).path "infra_results.csv"

# GraphQL query to fetch sub-account IDs
$subAccountQuery = ConvertTo-Json @{
    "query" = @"
        {
            actor {
                account(id: $accountId) {
                    subAccounts: nrql(query: "FROM NrDailyUsage SELECT uniques(subAccountId) as 'subAccountIds' SINCE 7 DAYS AGO LIMIT MAX", timeout: 90) {
                        results
                    }
                }
            }
        }
"@
}

# Sending the request to get sub-account IDs
$subAccountResponse = Invoke-RestMethod -Uri $apiEndpoint -Method Post -Headers @{ "Api-key" = $apiKey; "Content-Type" = "application/json"} -Body $subAccountQuery

# Extract sub-account IDs from response
$subAccountIds = $subAccountResponse.data.actor.account.subAccounts.results[0].subAccountIds

# Loop through each sub-account ID and run the apm and infra queries
foreach ($SubAccountId in $subAccountIds) {
    $detailedQuery = ConvertTo-Json @{
        "query" = @"
            {
                actor {
                    account(id: $accountId) {
                        apm: nrql(query: "SELECT count(*) FROM NrDailyUsage SINCE 7 DAYS AGO WHERE apmAgentVersion IS NOT NULL AND subAccountId = '$SubAccountId' LIMIT MAX FACET subAccountName, agentHostname, apmAppName, apmAgentVersion", timeout: 90) {
                            results
                        }
                        infra: nrql(query: "SELECT count(*) FROM NrDailyUsage SINCE 7 DAYS AGO WHERE infrastructureAgentVersion IS NOT NULL AND subAccountId = '$SubAccountId' LIMIT MAX FACET subAccountName, agentHostname, infrastructureAgentVersion", timeout: 90) {
                            results
                        }
                    }
                }
            }
"@
    }

    # Sending the detailed query for each sub-account
    $detailedResponse = Invoke-RestMethod -Uri $apiEndpoint -Method Post -Headers @{ "Api-key" = $apiKey; "Content-Type" = "application/json"} -Body $detailedQuery

    # Write the facets for each sub-account for APM to file
    foreach ($result in $detailedResponse.data.actor.account.apm.results) {
        $facets = $result.facet -join ", "
        Add-Content -Path $apmFilePath -Value $facets
    }

    # Write the facets for each sub-account for Infra to file
    foreach ($result in $detailedResponse.data.actor.account.infra.results) {
        $facets = $result.facet -join ", "
        Add-Content -Path $infraFilePath -Value $facets
    }
}
