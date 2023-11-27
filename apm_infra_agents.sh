# Script version: 1.5 - apm and infra agent list results saved to a file

# Generate a User API Key for a personal account
$API_KEY = 'User API Key'  # Replace with your actual New Relic User API Key

# Master account ID
$MasterAccountId = 'Master Account ID'  # Replace with your actual New Relic Master Account ID

# File paths for apm and infra results in the same directory as the script
$apmFilePath = Join-Path $PSScriptRoot "apm_results.txt"
$infraFilePath = Join-Path $PSScriptRoot "infra_results.txt"

# GraphQL query to fetch sub-account IDs
$subAccountQuery = ConvertTo-Json @{
    "query" = @"
        {
            actor {
                account(id: $MasterAccountId) {
                    subAccounts: nrql(query: "FROM NrDailyUsage SELECT uniques(subAccountId) as 'subAccountIds' SINCE 7 DAYS AGO LIMIT MAX", timeout: 5) {
                        results
                    }
                }
            }
        }
"@
}

# Sending the request to get sub-account IDs
$subAccountResponse = Invoke-RestMethod -Uri "https://api.eu.newrelic.com/graphql" -Method Post -Headers @{ "Api-key" = $API_KEY; "Content-Type" = "application/json"} -Body $subAccountQuery

# Extract sub-account IDs from response
$subAccountIds = $subAccountResponse.data.actor.account.subAccounts.results[0].subAccountIds

# Loop through each sub-account ID and run the apm and infra queries
foreach ($SubAccountId in $subAccountIds) {
    $detailedQuery = ConvertTo-Json @{
        "query" = @"
            {
                actor {
                    account(id: $MasterAccountId) {
                        apm: nrql(query: "SELECT count(*) FROM NrDailyUsage SINCE 7 DAYS AGO WHERE apmAgentVersion IS NOT NULL AND subAccountId = '$SubAccountId' LIMIT MAX FACET subAccountName, agentHostname, apmAppName, apmAgentVersion", timeout: 5) {
                            results
                        }
                        infra: nrql(query: "SELECT count(*) FROM NrDailyUsage SINCE 7 DAYS AGO WHERE infrastructureAgentVersion IS NOT NULL AND subAccountId = '$SubAccountId' LIMIT MAX FACET subAccountName, agentHostname, infrastructureAgentVersion", timeout: 5) {
                            results
                        }
                    }
                }
            }
"@
    }

    # Sending the detailed query for each sub-account
    $detailedResponse = Invoke-RestMethod -Uri "https://api.eu.newrelic.com/graphql" -Method Post -Headers @{ "Api-key" = $API_KEY; "Content-Type" = "application/json"} -Body $detailedQuery

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
