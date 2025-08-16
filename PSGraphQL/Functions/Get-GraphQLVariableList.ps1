function Get-GraphQLVariableList {
    <#
    .SYNOPSIS
        Gets a list of variable definitions from a GraphQL query.
    .DESCRIPTION
        Gets a list of variable (argument) names, types, and nullable status from a GraphQL operation.
    .PARAMETER Query
        The GraphQL operation (query or mutation) to obtain the variable definitions from.
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
        [Parameter(Mandatory = $true, ParameterSetName = "Query",
            ValueFromPipeline = $true,
            Position = 0)][ValidateLength(12, 1073741791)][Alias("Operation", "Mutation")][System.String]$Query,

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
        $ArgumentException = New-Object -TypeName ArgumentException -ArgumentList "Not a valid GraphQL query or mutation. Verify syntax and try again."

        # Get the raw GraphQL query content
        [string]$graphQlQuery = ""
        if ($PSBoundParameters.ContainsKey("FilePath")) {
            try {
                $graphQlQuery = Get-Content -Path $FilePath -Raw
            }
            catch {
                Write-Error "Unable to read file at path: $FilePath" -Category ReadError -ErrorAction Stop
            }
        }
        else {
            $graphQlQuery = $Query
        }

        # Ensure we have valid input
        if ([string]::IsNullOrWhiteSpace($graphQlQuery)) {
            Write-Error -Exception $ArgumentException -Category InvalidArgument -ErrorAction Stop
        }

        # Attempt to determine if value passed to the query parameter is an actual GraphQL query or mutation. If not, throw:
        # Updated regex pattern to be more flexible with GraphQL operation detection
        $graphqlOperationPattern = '^\s*(query|mutation|subscription)(\s+\w+)?\s*[\(\{]'
        if (-not ($graphQlQuery -match $graphqlOperationPattern)) {
            Write-Error -Exception $ArgumentException -Category InvalidArgument -ErrorAction Stop
        }

        # List of objects that are returned by default:
        $results = [System.Collections.Generic.List[GraphQLVariable]]::new()

        # Ensure $results is properly initialized
        if ($null -eq $results) {
            $results = [System.Collections.Generic.List[GraphQLVariable]]::new()
        }

        # Updated parsing logic based on Parse-GraphQLVariables
        # Regex to match variable definitions like $variableName: Type [= DefaultValue]
        $variablePattern = '\$(\w+):\s*([\w\[\]!]+)(?:\s*=\s*(".*?"|\d+|\w+|\[.*?\]|\{.*?\}))?'
        # Regex to detect operation start (query or mutation or subscription) - more flexible
        $operationPattern = '^\s*(query|mutation|subscription)(\s+(\w+))?\s*[\(\{]'

        # Split query into lines for processing
        $lines = $graphQlQuery -split '\r?\n'
        $currentOperation = $null
        $currentOperationType = $null
        $variables = @()

        foreach ($line in $lines) {
            # Trim whitespace
            $line = $line.Trim()
            # Skip empty lines or comments
            if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
                continue
            }

            # Check for new operation (query or mutation or subscription)
            if ($line -match $operationPattern) {
                # If we were processing a previous operation, save its variables
                if ($currentOperation -and $variables.Count -gt 0) {
                    # Process variables for the previous operation
                    foreach ($variable in $variables) {
                        $gqlVariable = [GraphQLVariable]::new()
                        $gqlVariable.HasVariables = $true
                        $gqlVariable.Operation = $currentOperation
                        $gqlVariable.OperationType = $currentOperationType
                        $gqlVariable.Parameter = $variable.Name
                        $gqlVariable.Type = ($variable.Type.Replace("!", "").Replace("[", "").Replace("]", ""))

                        if ($variable.Type.Contains("!")) {
                            $gqlVariable.Nullable = $false
                        }
                        else {
                            $gqlVariable.Nullable = $true
                        }

                        if ($variable.Type.Contains("[") -and $variable.Type.Contains("]")) {
                            $gqlVariable.IsArray = $true
                        }
                        else {
                            $gqlVariable.IsArray = $false
                        }

                        $gqlVariable.RawType = $variable.Type
                        $results.Add($gqlVariable)
                    }
                    $variables = @()
                }

                # Capture operation name (if provided) or type
                $currentOperationType = $Matches[1].ToLower()
                $currentOperation = if ($Matches[3]) { $Matches[3] } else { $Matches[1] }
            }

            # Check for variable definitions
            if ($line -match $variablePattern) {
                foreach ($match in [regex]::Matches($line, $variablePattern)) {
                    $variables += [PSCustomObject]@{
                        Name = $match.Groups[1].Value
                        Type = $match.Groups[2].Value
                        DefaultValue = if ($match.Groups[3].Success) { $match.Groups[3].Value } else { $null }
                    }
                }
            }
        }

        # Save variables for the last operation
        if ($currentOperation -and $variables.Count -gt 0) {
            foreach ($variable in $variables) {
                $gqlVariable = [GraphQLVariable]::new()
                $gqlVariable.HasVariables = $true
                $gqlVariable.Operation = $currentOperation
                $gqlVariable.OperationType = $currentOperationType
                $gqlVariable.Parameter = $variable.Name
                $gqlVariable.Type = ($variable.Type.Replace("!", "").Replace("[", "").Replace("]", ""))

                if ($variable.Type.Contains("!")) {
                    $gqlVariable.Nullable = $false
                }
                else {
                    $gqlVariable.Nullable = $true
                }

                if ($variable.Type.Contains("[") -and $variable.Type.Contains("]")) {
                    $gqlVariable.IsArray = $true
                }
                else {
                    $gqlVariable.IsArray = $false
                }

                $gqlVariable.RawType = $variable.Type
                $results.Add($gqlVariable)
            }
        }

        # If no operations with variables were found, return a single object with just operation info
        if ($results.Count -eq 0) {
            # Fallback to find at least one operation for basic info
            if ($graphQlQuery -match $graphqlOperationPattern) {
                $gqlVariable = [GraphQLVariable]::new()
                $gqlVariable.Operation = if ($Matches[2]) { $Matches[2].Trim() } else { $Matches[1] }
                $gqlVariable.OperationType = $Matches[1].ToLower()
                $results.Add($gqlVariable)
            }
            else {
                Write-Error -Exception $ArgumentException -Category InvalidArgument -ErrorAction Stop
            }
        }

        return $results
    }
}
