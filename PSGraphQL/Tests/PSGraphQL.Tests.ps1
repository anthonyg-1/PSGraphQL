#Requires -Modules @{ModuleName="Pester";ModuleVersion="4.10.1"}
#requires -Module PSScriptAnalyzer

$myDefaultDirectory = Get-Location

Set-Location -Path $myDefaultDirectory
Set-Location -Path ..

$module = 'PSGraphQL'

$moduleDirectory = Get-Item -Path $myDefaultDirectory | Select-Object -ExpandProperty FullName

Clear-Host

Describe "$module Module Structure and Validation Tests" -Tag Unit -WarningAction SilentlyContinue {
    Context "$module" {
        It "has the root module $module.psm1" {
            "$moduleDirectory/$module.psm1" | Should -Exist
        }

        It "has the a manifest file of $module.psd1" {
            "$moduleDirectory/$module.psd1" | Should -Exist
        }

        It "has Functions subdirectory" {
            "$moduleDirectory/Functions/*.ps1" | Should -Exist
        }

        It "$module is valid PowerShell code" {
            $psFile = Get-Content -Path "$moduleDirectory\$module.psm1" -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
            $errors.Count | Should -Be 0
        }
    }

    Context "Code Validation" {
        Get-ChildItem -Path "$moduleDirectory" -Filter *.ps1 -Recurse | ForEach-Object {
            It "$_ is valid PowerShell code" {
                $psFile = Get-Content -Path $_.FullName -ErrorAction Stop
                $errors = $null
                $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
                $errors.Count | Should -Be 0
            }
        }
    }

    Context "$module.psd1" {
        It "should not throw an exception in import" {
            $modPath = "$moduleDirectory/$module.psd1"
            { Import-Module -Name $modPath -Force -ErrorAction Stop } | Should Not Throw
        }
    }

}

Describe "Testing module and cmdlets against PSSA rules" -Tag Unit -WarningAction SilentlyContinue {
    $scriptAnalyzerRules = Get-ScriptAnalyzerRule

    Context "$module test against PSSA rules" {
        $modulePath = "$moduleDirectory\$module.psm1"

        $analysis = Invoke-ScriptAnalyzer -Path $modulePath

        foreach ($rule in $scriptAnalyzerRules) {
            It "should pass $rule" {
                If ($analysis.RuleName -contains $rule) {
                    $analysis | Where RuleName -eq $rule -OutVariable failures
                    $failures.Count | Should -Be 0
                }
            }
        }
    }

    Get-ChildItem -Path "$moduleDirectory\Functions" -Filter *.ps1 -Recurse | ForEach-Object {
        Context "$_ test against PSSA rules" {
            $analysis = Invoke-ScriptAnalyzer -Path $_.FullName -ExcludeRule PSUseShouldProcessForStateChangingFunctions

            foreach ($rule in $scriptAnalyzerRules) {
                It "should pass $rule" {
                    If ($analysis.RuleName -contains $rule) {
                        $analysis | Where RuleName -eq $rule -OutVariable failures
                        $failures.Count | Should -Be 0
                    }
                }
            }
        }
    }

    Get-ChildItem -Path "$moduleDirectory\PrivateFunctions" -Filter *.ps1 -Recurse | ForEach-Object {
        Context "$_ test against PSSA rules" {
            $analysis = Invoke-ScriptAnalyzer -Path $_.FullName -ExcludeRule PSUseShouldProcessForStateChangingFunctions

            foreach ($rule in $scriptAnalyzerRules) {
                It "should pass $rule" {
                    If ($analysis.RuleName -contains $rule) {
                        $analysis | Where RuleName -eq $rule -OutVariable failures
                        $failures.Count | Should -Be 0
                    }
                }
            }
        }
    }
}

Describe "Unit Tests for GraphQLVariableList" {
    $twoParamQuery = '
        query GetUsersByUserIdAndCustRecNumber($userId: Int!, $customerRecNum: String!) {
        users: active_users(
            where: {user_id: {_eq: $userId}, _and: {customer_rec_num: {_eq: $customerRecNum}, _and: {active_users: {user_id: {_is_null: false}}}}}
        ) {
            user: active_users {
            email: email_address
            firstName: first_name
            lastName: last_name
            lastLogin: last_login_date
            id: user_id
            }
        }
        }'

    $threeParamMutation = '
        mutation CreateUserInPlatform($firstName: String! = "", $lastName: String! = "", $email: String! = "") {
        createdUser: user_mgmt_create_user(
            user_input: {first_name: $firstName, last_name: $lastName, email_address: $email}
        ) {
            id: user_id
            firstName: first_name
            lastName: last_name
            email: email_address
        }
        }'

    $eightParamMutation = 'mutation UpdateUserAttributes($uuId: uuid!, $userId: String!, $firstName: String!, $lastName: String!, $userId: Int!, $roles: [user_roles!]!, $roleIds: [Int]!, $objects: [user_attributes!]!) {
        update_users(
            where: {user_id: {_eq: $uuId}}
            _set: {first_name: $firstName, last_name: $lastName}
        ) {
            affected_rows
        }
        insert_user_roles(objects: $roles) {
            returning {
            user_id
            role_id
            }
        }
        delete_user_roles(
            where: {role_id: {_in: $roleIds}, user_id: {_eq: $userId}}
        ) {
            affected_rows
        }
        insert_user_attributes(objects: $objects) {
            affected_rows
        }
}'

    $nineParamMutation = 'mutation UpdateUser($uuId: uuid!, $userId: String!, $firstName: String!, $middleName: String = "",$lastName: String!, $userId: Int!, $roles: [user_roles!]!, $roleIds: [Int!]!, $objects: [user_attributes!]!) {
        update_users(
            where: {user_id: {_eq: $uuId}}
            _set: {first_name: $firstName, last_name: $lastName}
        ) {
            affected_rows
        }
        delete_security_user(
            where: {user_id: {_eq: $userId}}
        ) {
            affected_rows
        }
        insert_user_roles(objects: $roles) {
            returning {
            user_id
            role_id
            }
        }
        delete_user_roles(
            where: {role_id: {_in: $roleIds}, user_id: {_eq: $userId}}
        ) {
            affected_rows
        }
        insert_user_attributes(objects: $objects) {
            affected_rows
        }
        }'

    $sevenParamMutation = 'mutation RoleChangeUpdateAccountUser($uuId: uuid!, $userId: String!, $firstName: String!, $lastName: String!, $roles: [user_roles!]!, $roleIds: [Int!]!, $userId: Int!) {
        update_users(
            where: {user_id: {_eq: $uuId}}
            _set: {first_name: $firstName, last_name: $lastName}
        ) {
            affected_rows
        }
        insert_security_users(
            objects: {user_id: $userId, user_id: $userId, active_indicator: true}
        ) {
            returning {
            active_users {
                user_id
                last_name
                first_name
                email_address
            }
            }
        }
        insert_user_roles(objects: $roles) {
            returning {
            user_id
            role_id
            }
        }
        delete_user_roles(
            where: {role_id: {_in: $roleIds}, user_id: {_eq: $userId}}
        ) {
            affected_rows
        }
        }'

    $sevenParamMutationMultiLine = '
        mutation UpdateUserTransactional(
            $uuId: uuid!,
            $userId: String!,
            $firstName: String!,
            $lastName: String!,
            $roles: [user_roles!]!,
            $roleIds: [Int!]!,
            $objects: [user_attributes!]!) {
        update_users(
            where: {user_id: {_eq: $uuId}}
            _set: {first_name: $firstName, last_name: $lastName}
        ) {
            affected_rows
        }
        insert_user_roles(objects: $roles) {
            returning {
            user_id
            role_id
            }
        }
        delete_user_roles(
            where: {user_id: {_eq: $userId}, _and: {role_id: {_in: $roleIds}}}
        ) {
            affected_rows
        }
        insert_user_attributes(objects: $objects) {
            affected_rows
        }
        delete_user_attributes(
            where: {user_id: {_eq: $userId}, _and: {serviced_location_id: {_in: $locationIds}}}
        ) {
            affected_rows
        }
        }'

    Context "Two variable query" {
        It "should discover two variables" {
            (GraphQLVariableList -Query $twoParamQuery | Measure).Count | Should Be 2
        }

        It "should contain the variable userId" {
            (GraphQLVariableList -Query $twoParamQuery).Parameter | Should Contain "userId"
        }

        It "should contain the variable customerRecNum" {
            (GraphQLVariableList -Query $twoParamQuery).Parameter | Should Contain "customerRecNum"
        }
    }

    Context "Three variable mutation" {
        It "should discover three variables" {
            (GraphQLVariableList -Query $threeParamMutation | Measure).Count | Should Be 3
        }

        It "should contain the variable firstName" {
            (GraphQLVariableList -Query $threeParamMutation).Parameter | Should Contain "firstName"
        }

        It "should contain the variable lastName" {
            (GraphQLVariableList -Query $threeParamMutation).Parameter | Should Contain "lastName"
        }

        It "should contain the variable email" {
            (GraphQLVariableList -Query $threeParamMutation).Parameter | Should Contain "email"
        }
    }

    Context "Eight variable mutation" {
        It "should discover eight variables" {
            (GraphQLVariableList -Query $eightParamMutation | Measure).Count | Should Be 8
        }

        It "should contain the variable uuid" {
            (GraphQLVariableList -Query $eightParamMutation).Parameter | Should Contain "uuid"
        }

        It "should contain the variable userId" {
            (GraphQLVariableList -Query $eightParamMutation).Parameter | Should Contain "userId"
        }

        It "should contain the variable firstName" {
            (GraphQLVariableList -Query $eightParamMutation).Parameter | Should Contain "firstName"
        }

        It "should contain the variable lastName" {
            (GraphQLVariableList -Query $eightParamMutation).Parameter | Should Contain "lastName"
        }

        It "should contain the variable roles" {
            (GraphQLVariableList -Query $eightParamMutation).Parameter | Should Contain "roles"
        }

        It "should contain the variable roleIds" {
            (GraphQLVariableList -Query $eightParamMutation).Parameter | Should Contain "roles"
        }

        It "should contain the variable objects" {
            (GraphQLVariableList -Query $eightParamMutation).Parameter | Should Contain "objects"
        }
    }

    Context "Nine variable mutation" {
        It "should discover nine variables" {
            (GraphQLVariableList -Query $nineParamMutation | Measure).Count | Should Be 9
        }

        It "should contain the variable uuid" {
            (GraphQLVariableList -Query $nineParamMutation).Parameter | Should Contain "uuid"
        }

        It "should contain the variable userId" {
            (GraphQLVariableList -Query $nineParamMutation).Parameter | Should Contain "userId"
        }

        It "should contain the variable firstName" {
            (GraphQLVariableList -Query $nineParamMutation).Parameter | Should Contain "firstName"
        }

        It "should contain the variable middleName" {
            (GraphQLVariableList -Query $nineParamMutation).Parameter | Should Contain "middleName"
        }

        It "should contain the variable lastName" {
            (GraphQLVariableList -Query $nineParamMutation).Parameter | Should Contain "lastName"
        }

        It "should contain the variable roles" {
            (GraphQLVariableList -Query $nineParamMutation).Parameter | Should Contain "roles"
        }

        It "should contain the variable roleIds" {
            (GraphQLVariableList -Query $nineParamMutation).Parameter | Should Contain "roles"
        }

        It "should contain the variable objects" {
            (GraphQLVariableList -Query $eightParamMutation).Parameter | Should Contain "objects"
        }
    }

    Context "Seven variable mutation" {
        It "should discover seven variables" {
            (GraphQLVariableList -Query $sevenParamMutation | Measure).Count | Should Be 7
        }

        It "should contain the variable uuid" {
            (GraphQLVariableList -Query $sevenParamMutation).Parameter | Should Contain "uuid"
        }

        It "should contain the variable userId" {
            (GraphQLVariableList -Query $sevenParamMutation).Parameter | Should Contain "userId"
        }

        It "should contain the variable firstName" {
            (GraphQLVariableList -Query $sevenParamMutation).Parameter | Should Contain "firstName"
        }

        It "should contain the variable lastName" {
            (GraphQLVariableList -Query $sevenParamMutation).Parameter | Should Contain "lastName"
        }

        It "should contain the variable roles" {
            (GraphQLVariableList -Query $sevenParamMutation).Parameter | Should Contain "roles"
        }

        It "should contain the variable roleIds" {
            (GraphQLVariableList -Query $sevenParamMutation).Parameter | Should Contain "roles"
        }

        It "should contain the variable userId twice, one of type String and one of type Int" {
            (GraphQLVariableList -Query $sevenParamMutation | Where Parameter -eq userId).Type | Should Contain "String"
            (GraphQLVariableList -Query $sevenParamMutation | Where Parameter -eq userId).Type | Should Contain "Int"
        }
    }

    Context "Seven variable mutation multi-line" {
        It "should discover seven variables" {
            (GraphQLVariableList -Query $sevenParamMutationMultiLine | Measure).Count | Should Be 7
        }

        It "should contain the variable uuid" {
            (GraphQLVariableList -Query $sevenParamMutationMultiLine).Parameter | Should Contain "uuid"
        }

        It "should contain the variable userId" {
            (GraphQLVariableList -Query $sevenParamMutationMultiLine).Parameter | Should Contain "userId"
        }

        It "should contain the variable firstName" {
            (GraphQLVariableList -Query $sevenParamMutationMultiLine).Parameter | Should Contain "firstName"
        }

        It "should contain the variable lastName" {
            (GraphQLVariableList -Query $sevenParamMutationMultiLine).Parameter | Should Contain "lastName"
        }

        It "should contain the variable roles" {
            (GraphQLVariableList -Query $sevenParamMutationMultiLine).Parameter | Should Contain "roles"
        }

        It "should contain the variable roleIds" {
            (GraphQLVariableList -Query $sevenParamMutationMultiLine).Parameter | Should Contain "roles"
        }
    }
}
