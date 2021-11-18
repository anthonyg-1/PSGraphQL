function Get-GraphQLVariableList {
    <#
    .SYNOPSIS
        Gets a list of variable definitions from a GraphQL query.
    .DESCRIPTION
        Gets a list of variable (argument) names, types, and nullable status from a GraphQL operation.
    .PARAMETER Query
        The GraphQL operation (query or mutation) to obtain the variable definitions from.
    .EXAMPLE
        $query = '
            query RollDice($dice: Int!, $sides: Int) {
            rollDice(numDice: $dice, numSides: $sides)
        }'

        Get-GraphQLVariableList -Query $query

        Gets a list of variable definitions from a GraphQL query.
    .EXAMPLE
        $wordListPath = ".\SQL.txt"
        $words = [IO.File]::ReadAllLines($wordListPath)

        $uri = "https://mytargetserver/v1/graphql"

        Get-GraphQLVariableList -Query $mutation | Where Type -eq "String" | ForEach-Object {
            $varName = $_.Parameter
            $opName = $_.Operation

            $words | ForEach-Object {
                $gqlVars = @{$varName=$_}

                Invoke-GraphQLQuery -Uri $uri -Mutation $mutation -OperationName $opName -Variables $gqlVars
            }
        }

        Read in a SQL injection word list, iterate through the results of the variable list, filter on type String, then iterate through the SQL injection word list to attempt SQL injection via fuzzing against each discovered parameter.
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
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0)][ValidateLength(12, 1073741791)][Alias("Operation", "Mutation")][System.String]$Query
    )
    BEGIN {
        class GraphQLVariable {
            [string]$Operation = ""
            [string]$Parameter = ""
            [string]$Type = ""
            [nullable[bool]]$Nullable = $null
            [nullable[bool]]$IsArray = $null
            [string]$RawType = ""
        }
    }
    PROCESS {
        # Exception to be used through the function in the case that an invalid GraphQL query or mutation is passed:
        $ArgumentException = New-Object -TypeName ArgumentException -ArgumentList "Not a valid GraphQL query or mutation. Verify syntax and try again."

        # Compress and trim the incoming query for all operations within this function:
        [string]$cleanedQueryInput = Compress-String -InputString $Query

        # Attempt to determine if value passed to the query parameter is an actual GraphQL query or mutation. If not, throw:
        if (($cleanedQueryInput -notlike "query*") -and ($cleanedQueryInput -notlike "mutation*") ) {
            Write-Error -Exception $ArgumentException -Category InvalidArgument -ErrorAction Stop
        }

        # Get the query name via regex and splitting on the first space after query or mutation:
        $matchOnParanOrCurlyRegex = '^[^\(|{]+'
        $operationName = [regex]::Match(($cleanedQueryInput.Split(" ")[1]), $matchOnParanOrCurlyRegex) | Select-Object -ExpandProperty Value

        # List of objects that are returned by default:
        $results = [List[GraphQLVariable]]::new()

        # Run a regex against the incoming query looking for property name and type that does not return default parameter values:
        [string]$queryNameAndTypeRegex = "(?<=\$)[_A-Za-z][_0-9A-Za-z]*:[\s]*\[*[_A-Za-z][_0-9A-Za-z]*\!?\]*\!?(?=[\x20-\xFF]*[,\)])"
        $possibleMatches = [regex]::Matches($cleanedQueryInput, $queryNameAndTypeRegex)

        # If we get matches, add to results list. Else, return a single object in the list containing the operation name only:
        if ($possibleMatches.Count -gt 0) {
            $possibleMatches | Select-Object -ExpandProperty Value | ForEach-Object {
                $parameterName = ($_.Split(":")[0]).Trim()
                $parameterType = ($_.Split(":")[1]).Trim()

                $gqlVariable = [GraphQLVariable]::new()
                $gqlVariable.Operation = $operationName
                $gqlVariable.Parameter = $parameterName
                $gqlVariable.Type = ($parameterType.Replace("!", "").Replace("[", "").Replace("]", ""))

                if ($parameterType.Contains("!")) {
                    $gqlVariable.Nullable = $false
                }
                else {
                    $gqlVariable.Nullable = $true
                }

                if ($parameterType.Contains("[") -and $parameterType.Contains("[")) {
                    $gqlVariable.IsArray = $true
                }
                else {
                    $gqlVariable.IsArray = $false
                }

                $gqlVariable.RawType = $parameterType
                $results.Add($gqlVariable)
            }
        }
        else {
            $gqlVariable = [GraphQLVariable]::new()
            $gqlVariable.Operation = $operationName
            $results.Add($gqlVariable)
        }

        return $results
    }
}
