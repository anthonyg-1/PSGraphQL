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

        Get-GraphQLVariableList -Query $query | Format-Table

        Gets a list of variable definitions from a GraphQL query and renders the results to the console as a table.
    .EXAMPLE
        $mutation = '
            mutation AddNewPet ($name: String!, $petType: PetType, $petLocation: String!, $petId: Int!) {
                    addPet(name: $name, petType: $petType, location: $petLocation, id: $petId) {
                    name
                    petType
                    location
                    id
                }
            }'

        $wordListPath = ".\SQL.txt"
        $words = [IO.File]::ReadAllLines($wordListPath)

        $uri = "https://mytargetserver/v1/graphql"

        # Array to store results from Invoke-GraphQLQuery -Detailed for later analysis:
        $results = @()

        # Get the variable definition from the supplied mutation:
        $variableList = $mutation | Get-GraphQLVariableList

        $words | ForEach-Object {
        $queryVarTable = @{}
        $word = $_

        $variableList | Select Parameter, Type | ForEach-Object {
            $randomInt = Get-Random
                if ($_.Type -eq "Int") {
                    if (-not($queryVarTable.ContainsKey($_.Parameter))) {
                        $queryVarTable.Add($_.Parameter, $randomInt)
                    }
                }
                else {
                if (-not($queryVarTable.ContainsKey($_.Parameter))) {
                        $queryVarTable.Add($_.Parameter, $word)
                    }
                }
            }

            $gqlResult = Invoke-GraphQLQuery -Mutation $mutation -Variables $queryVarTable -Headers $headers -Uri $uri -Detailed
            $result = [PSCustomObject]@{ParamValues=($queryVarTable);Result=($gqlResult)}
            $results += $result
        }

        Iterate through a SQL injection word list, generate a random integer for parameters of type Int, use the current word in the word list for all other variables, attempt to fuzz each GraphQL parameter for the defined mutation at the target endpoint.
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
        $ArgumentException = New-Object -TypeName ArgumentException -ArgumentList "Not a valid GraphQL query or mutation. Verify syntax and try again."

        # Compress and trim the incoming query for all operations within this function:
        [string]$cleanedQueryInput = Compress-String -InputString $Query

        # Attempt to determine if value passed to the query parameter is an actual GraphQL query or mutation. If not, throw:
        if (($cleanedQueryInput -notlike "query*") -and ($cleanedQueryInput -notlike "mutation*") ) {
            Write-Error -Exception $ArgumentException -Category InvalidArgument -ErrorAction Stop
        }

        # Get the operation name and type via regex and splitting on the first space after query or mutation:
        $matchOnParanOrCurlyRegex = '^[^\(|{]+'
        $operationName = [regex]::Match(($cleanedQueryInput.Split(" ")[1]), $matchOnParanOrCurlyRegex) | Select-Object -ExpandProperty Value
        $operationType = ([regex]::Match(($cleanedQueryInput.Split(" ")[0]), $matchOnParanOrCurlyRegex) | Select-Object -ExpandProperty Value).ToLower()

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
                $gqlVariable.HasVariables = $true
                $gqlVariable.Operation = $operationName
                $gqlVariable.OperationType = $operationType
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
            $gqlVariable.OperationType = $operationType
            $results.Add($gqlVariable)
        }

        return $results
    }
}
