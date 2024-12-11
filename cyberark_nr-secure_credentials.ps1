$ProgressPreference = "SilentlyContinue"

$NewRelicGraphQLEndpoint = 'https://api.newrelic.com/graphql'
$accountId = '1234567'
$apiKey = 'NRAK-XXXX'
$secureCredentialName = 'MY_PASSWORD'

$CyberarkEndpoint = 'https://my-cyberark-endpoint.com'

# Get CyberArk credentials
$CyberarkRequest = Invoke-WebRequest -ContentType "application/json" -Uri $CyberarkEndpoint 

$CyberarkResponse = $CyberarkRequest | Select-Object Content -ExpandProperty Content | ConvertFrom-Json

$CyberarkPassword = $CyberarkResponse.Content

# Update secure credentials
$MUTATION = @{"query" = @"
mutation {
  syntheticsUpdateSecureCredential (
    accountId: $accountId, 
    key: $secureCredentialName, 
    value: $CyberarkPassword) {
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

if ($createExportResponse.errors) {
    Write-Output "Error: $($updateSecureCredential.errors[0].message)"
    exit
}