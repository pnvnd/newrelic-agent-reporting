$ProgressPreference = "SilentlyContinue"

$NewRelicGraphQLEndpoint = 'https://api.newrelic.com/graphql'
$accountId = '1234567'
$apiKey = 'NRAK-XXXXXXXXXXXXXXXXXXXXXXXXXXX'
$secureCredentialName = 'MY_PASSWORD'

$CyberarkEndpoint = 'https://raw.githubusercontent.com/pnvnd/newrelic-agent-reporting/refs/heads/main/cyberark.json'

# Get CyberArk credentials
$CyberarkRequest = Invoke-WebRequest -ContentType "application/json" -Uri $CyberarkEndpoint 
$CyberarkResponse = $CyberarkRequest | Select-Object Content -ExpandProperty Content | ConvertFrom-Json
$CyberarkPassword = $CyberarkResponse.Content
# Write-Output $CyberarkPassword

# Update secure credentials
$MUTATION = @{"query" = @"
mutation {
  syntheticsUpdateSecureCredential (
    accountId: $accountId,
    key: "$secureCredentialName",
    value: "$CyberarkPassword",
    description: "Description of MY_PASSWORD") {
    createdAt
    lastUpdate
    errors {
      description
    }
  }
}
"@
} | ConvertTo-Json

$updateSecureCredential = Invoke-WebRequest -Uri $NewRelicGraphQLEndpoint `
  -Method POST `
  -Headers @{ "Api-Key" = $apiKey } `
  -ContentType "application/json" `
  -Body $MUTATION

$updateSecureCredentialResponse = $updateSecureCredential | Select-Object Content -ExpandProperty Content | ConvertFrom-Json

# Write-Output $updateSecureCredentialResponse

if ($updateSecureCredentialResponse.errors) {
    Write-Output "Error: $($updateSecureCredentialResponse.errors[0].message)"
    exit
}