function Invoke-GraphQLQuery {
    <#
    .SYNOPSIS
        Sends a query to a GraphQL endpoint.
    .DESCRIPTION
        Sends a query (read operation) or mutation (create, update, delete operation) to a GraphQL endpoint.
    .PARAMETER Query
        The GraphQL query or mutation to send to the endpoint.
    .PARAMETER Headers
        Specifies the headers of the web request. Enter a hash table or dictionary.
    .PARAMETER Uri
        Specifies the Uniform Resource Identifier (URI) of the GraphQL endpoint to which the query or mutation is sent.
    .PARAMETER Raw
        Tells the function to return JSON as opposed to objects.
    .NOTES
        Query and mutation default return type is a collection of objects. To return a query result as JSON, use the -Raw switch.
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

        Invoke-GraphQLQuery -Query $myQuery -Headers $requestHeaders -Uri $url -Raw

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

        $result = Invoke-GraphQLQuery -Query $myQuery -Headers $requestHeaders -Uri $url
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

        $jsonResult = Invoke-GraphQLQuery -Mutation $myMutation -Headers $requestHeaders -Uri $url -Raw

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

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $false,
            Position = 1)][Alias("h")][System.Collections.Hashtable]$Headers,

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $false,
            Position = 2)][Alias("u")][System.Uri]$Uri,

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

        if ($PSBoundParameters.ContainsKey("Raw")) {
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
