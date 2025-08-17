function Get-GraphQLVariableList {
    <#
    .SYNOPSIS
        Gets a list of variable definitions from a GraphQL query.
    .DESCRIPTION
        Gets a list of variable (argument) names, types, and nullable status from a GraphQL operation.
    .PARAMETER Query
        The GraphQL operation (query, mutation, subscription, or fragment) to obtain the variable definitions from.
    .PARAMETER FilePath
        The path to a file containing a GraphQL query to obtain the variable definitions from.
    .EXAMPLE
        $query = '
            query RollDice($dice: Int!, $sides: Int) {
            rollDice(numDice: $dice, numSides: $sides)
        }'

        Get-GraphQLVariableList -Query $query | Format-Table

        Gets a list of variable definitions from a GraphQL query and renders the results to the console as a table.
    .EXAMPLE
        $queryFilePath = "./queries/rolldice.gql"
        Get-GraphQLVariableList -FilePath $queryFilePath

        Gets a list of variable definitions from a file containing a GraphQL query and renders the results to the console as a table.
    .EXAMPLE
        $fragment = '
            fragment UserInfo($includeEmail: Boolean!) on User {
                name
                email @include(if: $includeEmail)
            }'

        Get-GraphQLVariableList -Query $fragment

        Gets a list of variable definitions from a GraphQL fragment.
    .INPUTS
        System.String
    .LINK
        https://graphql.org/
        Format-Table
        Invoke-GraphQLQuery
    #>
    [CmdletBinding()]
    [Alias('ggqlvl')]
    [OutputType([GraphQLVariable], [System.Collections.Hashtable])]
    <##>
    Param
    (
        [Parameter(Mandatory = $true, ParameterSetName = "Query",
            ValueFromPipeline = $true,
            Position = 0)][ValidateLength(12, 1073741791)][Alias("Operation", "Mutation", "Fragment")][System.String]$Query,

        [Parameter(Mandatory = $false, ParameterSetName = "FilePath", Position = 0)][ValidateNotNullOrEmpty()][Alias('f', 'Path')][System.IO.FileInfo]$FilePath

    )
    BEGIN {
        class GraphQLVariable {
            [bool]$HasVariables = $false
            [string]$Operation = ""
            [string]$OperationType = ""
            [string]$Parameter = ""
            [string]$Type = ""
            [nullable[bool]]$Nullable = $null
            [nullable[bool]]$IsArray = $null
            [string]$RawType = ""
        }
    }
    PROCESS {
        # Exception to be used through the function in the case that an invalid GraphQL query or mutation is passed:
        $ArgumentException = New-Object -TypeName ArgumentException -ArgumentList "Not a valid GraphQL operation (query, mutation, subscription, or fragment). Verify syntax and try again."

        # Get the raw GraphQL query content
        [string]$graphQlQuery = $Query

        if ($PSBoundParameters.ContainsKey("FilePath")) {
            if (Test-Path -Path $FilePath) {
                $graphQlQuery = Get-Content -Path $FilePath -Raw
            }
            else {
                Write-Error "Unable to read file at path: $FilePath" -Category ReadError -ErrorAction Stop
            }
        }

        # Ensure we have valid input
        if ([string]::IsNullOrWhiteSpace($graphQlQuery)) {
            Write-Error -Exception $ArgumentException -Category InvalidArgument -ErrorAction Stop
        }

        # Remove comments and normalize whitespace
        $cleanQuery = $graphQlQuery -replace '#[^\r\n]*', '' -replace '\s+', ' '

        # Simple check for operation keywords
        if (-not ($cleanQuery -match '(query|mutation|subscription|fragment)')) {
            Write-Error -Exception $ArgumentException -Category InvalidArgument -ErrorAction Stop
        }

        # List of objects that are returned by default:
        $results = [System.Collections.Generic.List[GraphQLVariable]]::new()

        # Parse the entire query at once using more comprehensive regex
        # This regex captures: operation type, optional name, optional variables in parentheses, optional "on Type" for fragments
        $fullOperationPattern = '(query|mutation|subscription|fragment)\s*([a-zA-Z_][a-zA-Z0-9_]*)?\s*(\([^)]+\))?\s*(on\s+[a-zA-Z_][a-zA-Z0-9_]*)?\s*\{'

        # Variable pattern to extract individual variables from the parentheses
        $variablePattern = '\$([a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*([a-zA-Z0-9_\[\]!]+)(?:\s*=\s*[^,)]+)?'

        $operationMatches = [regex]::Matches($cleanQuery, $fullOperationPattern, 'IgnoreCase')

        if ($operationMatches.Count -eq 0) {
            Write-Error -Exception $ArgumentException -Category InvalidArgument -ErrorAction Stop
        }

        foreach ($operationMatch in $operationMatches) {
            $operationType = $operationMatch.Groups[1].Value.ToLower()
            $operationName = if ($operationMatch.Groups[2].Success) { $operationMatch.Groups[2].Value } else { $operationType }
            $variablesSection = if ($operationMatch.Groups[3].Success) { $operationMatch.Groups[3].Value } else { "" }
            $onType = if ($operationMatch.Groups[4].Success) { $operationMatch.Groups[4].Value } else { "" }

            # For fragments, include the "on Type" part in the operation name if present
            if ($operationType -eq "fragment" -and $onType) {
                $operationName = if ($operationMatch.Groups[2].Success) {
                    "$($operationMatch.Groups[2].Value) $onType"
                } else {
                    $onType
                }
            }

            # Extract variables from the variables section
            if ($variablesSection) {
                $variableMatches = [regex]::Matches($variablesSection, $variablePattern)

                if ($variableMatches.Count -gt 0) {
                    foreach ($variableMatch in $variableMatches) {
                        $paramName = $variableMatch.Groups[1].Value
                        $rawType = $variableMatch.Groups[2].Value

                        $gqlVariable = [GraphQLVariable]::new()
                        $gqlVariable.HasVariables = $true
                        $gqlVariable.Operation = $operationName
                        $gqlVariable.OperationType = $operationType
                        $gqlVariable.Parameter = $paramName
                        $gqlVariable.RawType = $rawType

                        # Parse type information
                        $cleanType = $rawType -replace '[\[\]!]', ''
                        $gqlVariable.Type = $cleanType

                        # Check if nullable (! means non-null, so nullable = false if ! is present)
                        $gqlVariable.Nullable = -not $rawType.Contains('!')

                        # Check if array
                        $gqlVariable.IsArray = $rawType.Contains('[') -and $rawType.Contains(']')

                        $results.Add($gqlVariable)
                    }
                } else {
                    # Operation exists but no variables
                    $gqlVariable = [GraphQLVariable]::new()
                    $gqlVariable.HasVariables = $false
                    $gqlVariable.Operation = $operationName
                    $gqlVariable.OperationType = $operationType
                    $results.Add($gqlVariable)
                }
            } else {
                # Operation exists but no variables section
                $gqlVariable = [GraphQLVariable]::new()
                $gqlVariable.HasVariables = $false
                $gqlVariable.Operation = $operationName
                $gqlVariable.OperationType = $operationType
                $results.Add($gqlVariable)
            }
        }

        if ($results.Count -eq 0) {
            Write-Error -Exception $ArgumentException -Category InvalidArgument -ErrorAction Stop
        }

        return $results
    }
}
