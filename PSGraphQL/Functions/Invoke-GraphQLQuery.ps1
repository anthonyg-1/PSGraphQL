function Invoke-GraphQLQuery {
    <#
    .SYNOPSIS
        Sends a query to a GraphQL endpoint.
    .DESCRIPTION
        Sends a query (read operation) or mutation (create, update, delete operation) to a GraphQL endpoint.
    .NOTES
        Mutation results are returned as JSON strings while query results are implicitly returned as objects. To return a query result as JSON, use the -Raw switch.
    .EXAMPLE
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

        Invoke-GraphQLQuery -Query $myQuery -Uri $url -Headers $requestHeaders -Raw

        Sends a GraphQL query to the endpoint 'https://mytargetserver/v1/graphql' with the results returned as JSON.
    .EXAMPLE
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

        $result = Invoke-GraphQLQuery -Query $myQuery -Uri $url -Headers $requestHeaders
        $result.data.users | Format-Table

        Sends a GraphQL query to the endpoint 'https://mytargetserver/v1/graphql' with the results returned as an object and navigates the hierarchy to return a table view of users.
    .EXAMPLE
        $url = "https://mytargetserver/v1/graphql"

        $myMutation = '
            mutation MyMutation {
                insert_users_one(object: {id: "57", name: "FirstName LastName"}) {
                id
            }
        }
        '

        $requestHeaders = @{ myApiKey="aoMGY{+93dx&t!5)VMu4pI8U8T.ULO" }

        $jsonResult = Invoke-GraphQLQuery -Mutation $myMutation -Uri $url -Headers $requestHeaders

        Sends a GraphQL mutation to the endpoint 'https://mytargetserver/v1/graphql' with the results returned as JSON.
    .LINK
        https://graphql.org/
        Format-Table
    #>
    [CmdletBinding()]
    [Alias("Invoke-GraphQLMutation","gql")]
    [OutputType([System.Management.Automation.PSCustomObject],[System.String])]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $false,
            Position = 0)][ValidateLength(12, 1073741791)][Alias("Mutation","q","m")][System.String]$Query,

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $false,
            Position = 1)][Alias("u")][System.Uri]$Uri,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $false,
            Position = 2)][Alias("h")][System.Collections.Hashtable]$Headers,

        [Parameter(Mandatory = $false,ParameterSetName="JSON",
            Position = 3)][Alias("AsJson","json","r")][Switch]$Raw
    )
    PROCESS {
        [string]$cleanedInput = $Query -replace '\s+', ' '
        [string]$jsonRequestBody = ""

        try {
            $jsonRequestBody = @{query = $cleanedInput } | ConvertTo-Json -Compress -ErrorAction Stop
        }
        catch {
            Write-Error -Exception $_.Exception -ErrorAction Stop
        }

        $response = $null
        try {
            $response = Invoke-RestMethod -Uri $Uri -Method Post -Headers $Headers -Body $jsonRequestBody -ContentType "application/json" -ErrorAction Stop
        }
        catch {
            Write-Error -Exception $_.Exception -ErrorAction Stop
        }

        [bool]$isMutation = $false
        if ($cleanedInput.ToLower() -match "mutation ") {
            $isMutation = $true
        }

        if ($PSBoundParameters.ContainsKey("Raw") -or $isMutation) {
            try {
                return $($response | ConvertTo-Json -Depth 100 -ErrorAction Stop)
            }
            catch {
                Write-Error -Exception $_.Exception -ErrorAction Stop
            }
        }
        else {
            try {
                return $response
            }
            catch {
                Write-Error -Exception $_.Exception -ErrorAction Stop
            }
        }
    }
}
