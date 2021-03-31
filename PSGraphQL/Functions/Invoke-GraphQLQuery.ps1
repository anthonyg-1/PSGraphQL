function Invoke-GraphQLQuery {
    <#
    .SYNOPSIS
        Sends a query or mutation to a GraphQL endpoint.
    .DESCRIPTION
        Sends a query (read operation) or mutation (create, update, delete operation) to a GraphQL endpoint.
    .PARAMETER Query
        The GraphQL query or mutation to send to the endpoint.
    .PARAMETER Headers
        Specifies the headers of the web request expressed as a hash table.
    .PARAMETER Uri
        Specifies the Uniform Resource Identifier (URI) of the GraphQL endpoint to which the GraphQL query or mutation is sent.
    .PARAMETER WebSession
        Specifies a web request session. Enter the variable name, including the dollar sign (`$`).
    .PARAMETER Raw
        Tells the function to return JSON as opposed to objects.
    .NOTES
        Query and mutation default return type is a collection of objects. To return results as JSON, use the -Raw switch.
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
    .EXAMPLE
        $targetHost = "gqlserver01"
        $gqlEndpointUri = "https://{0}/graphql" -f $targetHost

        $session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
        $cookine = [System.Net.Cookie]::new()
        $cookie.Name = "env"
        $cookie.Value = "dCLaUp2JSy2-+R#LSOa#IA7xsD"
        $cookie.Domain = $targetHost
        $session.Cookies.Add($cookie)

        Invoke-GraphQLQuery -Query $reconQuery -Uri $gqlEndpointUri -WebSession $session -Raw

        Initiates a GraphQL query with the web request session defined in the $session variable.
    .LINK
        https://graphql.org/
        Format-Table
    #>
    [CmdletBinding()]
    [Alias("gql")]
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

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $false,
            Position = 3)][Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [Parameter(Mandatory = $false,ParameterSetName="JSON",
            Position = 4)][Alias("AsJson","json","r")][Switch]$Raw
    )
    PROCESS {
        [string]$cleanedInput = ($Query -replace '\s+', ' ').Trim()

        if (($cleanedInput -notlike "query *") -and ($cleanedInput -notlike "mutation *") ) {
            $ArgumentException = New-Object -TypeName ArgumentException -ArgumentList "Not a valid GraphQL query or mutation. Verify syntax and try again."
            Write-Error -Exception $ArgumentException -ErrorAction Stop
        }

        [string]$jsonRequestBody = ""
        try {
            $jsonRequestBody = @{query = $cleanedInput } | ConvertTo-Json -Compress -ErrorAction Stop
        }
        catch {
            Write-Error -Exception $_.Exception -ErrorAction Stop
        }

        $params = @{Uri=$Uri
                    Method="Post"
                    Body=$jsonRequestBody
                    ContentType="application/json"
                    ErrorAction="Stop"}

        if ($PSBoundParameters.ContainsKey("Headers")) {
            $params.Add("Headers",$Headers)
        }

        if ($PSBoundParameters.ContainsKey("WebSession")) {
            $params.Add("WebSession",$WebSession)
        }

        $response = $null
        try {
            $response = Invoke-RestMethod @params
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
