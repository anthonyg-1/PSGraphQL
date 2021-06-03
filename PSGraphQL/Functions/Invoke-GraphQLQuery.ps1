function Invoke-GraphQLQuery {
    <#
    .SYNOPSIS
        Sends a query or mutation to a GraphQL endpoint.
    .DESCRIPTION
        Sends a query (read operation) or mutation (create, update, delete operation) to a GraphQL endpoint.
    .PARAMETER Query
        The GraphQL query or mutation to send to the endpoint.
    .PARAMETER OperationName
        A meaningful and explicit name for your GraphQL operation.
    .PARAMETER Variables
        Variables expressed as a hash table for your GraphQL operation.
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
        $uri = "https://mytargetserver/v1/graphql"

        $query = '
            query RollDice($dice: Int!, $sides: Int) {
                rollDice(numDice: $dice, numSides: $sides)
            }'

        $variables = @{dice=3; sides=6}

        Invoke-GraphQLQuery -Query $query -Variables $variables -Uri $uri

        Sends a GraphQL query to the endpoint 'https://mytargetserver/v1/graphql' with variables defined in $variables.
    .EXAMPLE
        $uri = "https://mytargetserver/v1/graphql"

        $introspectionQuery = '
            query allSchemaTypes {
                __schema {
                    types {
                        name
                        kind
                        description
                    }
                }
            }
        '

        Invoke-GraphQLQuery -Query $introspectionQuery -Uri $uri -Raw

        Sends a GraphQL introspection query to the endpoint 'https://mytargetserver/v1/graphql' with the results returned as JSON.
    .EXAMPLE
        $uri = "https://mytargetserver/v1/graphql"

        $results = Invoke-GraphQLQuery -Uri $uri

        Sends a GraphQL introspection query using the default value for the Query parameter (as opposed to specifying it) to the endpoint 'https://mytargetserver/v1/graphql' with the results returned as objects and assigning the results to the $results variable.
    .EXAMPLE
        $uri = "https://mytargetserver/v1/graphql"

        $myQuery = '
            query GetUsers {
                users {
                    created_at
                    id
                    last_seen
                    name
                }
            }
        '

        Invoke-GraphQLQuery -Query $myQuery -Uri $uri -Raw

        Sends a GraphQL query to the endpoint 'https://mytargetserver/v1/graphql' with the results returned as JSON.
    .EXAMPLE
        $uri = "https://mytargetserver/v1/graphql"

        $myQuery = '
            query GetUsers {
                users {
                    created_at
                    id
                    last_seen
                    name
            }
        }
        '

        $result = Invoke-GraphQLQuery -Query $myQuery -Uri $uri
        $result.data.users | Format-Table

        Sends a GraphQL query to the endpoint 'https://mytargetserver/v1/graphql' with the results returned as objects and navigates the hierarchy to return a table view of users.
    .EXAMPLE
        $jwt = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE2MjAzOTMwMjgsIm5iZiI6MTYyMDM5MzAyNywiZXhwIjoxNjIwMzkzMzI4LCJzdWIiOiJtZUBjb21wYW55LmNvbSIsImp0aSI6ImMwZTk0ZTY0ODc4ZjRlZDFhZWM3YWYwYzViOWM2ZWI5Iiwicm9sZSI6InVzZXIifQ.HaTXDunEjmyUsHs7daLe-AxEpmq58QqqFziydm7MBic"

        $headers = @{Authorization="Bearer $jwt"}

        $uri = "https://mytargetserver/v1/graphql"

        $myQuery = '
            query GetUsers {
                users {
                    created_at
                    id
                    last_seen
                    name
            }
        }
        '

        $result = Invoke-GraphQLQuery -Query $myQuery -Headers $headers -Uri $uri
        $result.data.users | Format-Table

        Sends a GraphQL query using JWT for authentication to the endpoint 'https://mytargetserver/v1/graphql' with the results returned as objects and navigates the hierarchy to return a table view of users.
    .EXAMPLE
        $uri = "https://mytargetserver/v1/graphql"

        $myMutation = '
            mutation MyMutation {
                insert_users_one(object: {id: "57", name: "FirstName LastName"}) {
                id
            }
        }
        '

        $requestHeaders = @{ "x-api-key"="aoMGY{+93dx&t!5)VMu4pI8U8T.ULO" }

        $jsonResult = Invoke-GraphQLQuery -Mutation $myMutation -Headers $requestHeaders -Uri $uri -Raw

        Sends a GraphQL mutation to the endpoint 'https://mytargetserver/v1/graphql' with the results returned as JSON.
    .EXAMPLE
        gql -q 'query { users { created_at id last_seen name } }' -u 'https://mytargetserver/v1/graphql' -

        Sends a GraphQL query to an endpoint with the results returned as JSON (as a one-liner using aliases).
    .LINK
        https://graphql.org/
        Format-Table
        https://docs.microsoft.com/en-us/dotnet/api/microsoft.powershell.commands.webrequestsession?view=powershellsdk-7.0.0
    #>
    [CmdletBinding()]
    [Alias("gql")]
    [OutputType([System.Management.Automation.PSCustomObject], [System.String])]
    Param
    (
        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $false,
            Position = 0)][ValidateLength(12, 1073741791)][Alias("Mutation", "q", "m")][System.String]$Query = "query introspection { __schema { types { name kind description } } }",

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $false,
            Position = 1)][ValidateLength(1, 4096)][Alias("op")][System.String]$OperationName,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $false,
            Position = 2)][ValidateNotNullOrEmpty()][Alias("v")][System.Collections.Hashtable]$Variables,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $false,
            Position = 3)][Alias("h")][System.Collections.Hashtable]$Headers,

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $false,
            Position = 4)][Alias("u")][System.Uri]$Uri,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $false,
            Position = 5)][Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [Parameter(Mandatory = $false, ParameterSetName = "JSON",
            Position = 6)][Alias("AsJson", "json", "r")][Switch]$Raw

    )
    BEGIN {
        function Compress-String([string]$InputString) {
            return ($InputString -replace '\s+', ' ').Trim()
        }
    }
    PROCESS {

        # The object that will ultimately be serialized and sent to the GraphQL endpoint:
        $jsonRequestObject = [ordered]@{ }

        # Trim all spaces and flatten $OperationName parameter value and add to $jsonRequestObject:
        if ($PSBoundParameters.ContainsKey("OperationName")) {
            $cleanedOperationInput = Compress-String -InputString $OperationName
            $jsonRequestObject.Add("operationName", $cleanedOperationInput)
        }

        # Add $Variables hashtable to $jsonRequestObject:
        if ($PSBoundParameters.ContainsKey("Variables")) {
            $jsonRequestObject.Add("variables", $Variables)
        }

        # Trim all spaces and flatten $Query parameter value and add to $jsonRequestObject:
        $cleanedQueryInput = Compress-String -InputString $Query
        if (($cleanedQueryInput.ToLower() -notlike "query*") -and ($cleanedQueryInput.ToLower() -notlike "mutation*") ) {
            $ArgumentException = New-Object -TypeName ArgumentException -ArgumentList "Not a valid GraphQL query or mutation. Verify syntax and try again."
            Write-Error -Exception $ArgumentException -ErrorAction Stop
        }

        # Add $Query $jsonRequestObject:
        $jsonRequestObject.Add("query", $cleanedQueryInput)

        # Serialize $jsonRequestObject:
        [string]$jsonRequestBody = ""
        try {
            $jsonRequestBody = $jsonRequestObject | ConvertTo-Json -Compress -ErrorAction Stop
        }
        catch {
            Write-Error -Exception $_.Exception -ErrorAction Stop
        }

        $params = @{Uri = $Uri
            Method      = "Post"
            Body        = $jsonRequestBody
            ContentType = "application/json"
            ErrorAction = "Stop"
        }

        if ($PSBoundParameters.ContainsKey("Headers")) {
            $params.Add("Headers", $Headers)
        }

        if ($PSBoundParameters.ContainsKey("WebSession")) {
            $params.Add("WebSession", $WebSession)
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
