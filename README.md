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
