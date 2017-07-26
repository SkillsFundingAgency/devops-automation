function New-Password {
    <#

    .SYNOPSIS
    Generate a random password

    .DESCRIPTION
    Generate a random password using System.Web.Security.Membership::GeneratePassword()

    .PARAMETER Length
    The number of characters in the generated password. The length must be between 1 and 128 characters.

    .PARAMETER NumberOfNonAlphaNumericCharacters
    The minimum number of non-alphanumeric characters (such as @, #, !, %, &, and so on) in the generated password.

    .EXAMPLE
    New-Password

    .EXAMPLE
    New-Password -Length 20 -NumberOfNonAlphaNumericCharacters 2

    .NOTES

    Suppressed Script Analyzer rules:
        - PSAvoidUsingConvertToSecureStringWithPlainText - This method is used as the property is passed as a parameter to another function
        - PSUseShouldProcessForStateChangingFunctions - The function does not alter the state of an object

    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]  
    Param(
        [Parameter(Mandatory=$false)]
        [Int]$Length = 15,
        [Parameter(Mandatory=$false)]
        [Int]$NumberOfNonAlphaNumericCharacters = 0
    )

    try {
        # --- https://msdn.microsoft.com/en-us/library/system.web.security.membership.generatepassword.aspx
        $null = [Reflection.Assembly]::LoadWithPartialName("System.Web")
        $Password = [System.Web.Security.Membership]::GeneratePassword($Length,$NumberOfNonAlphaNumericCharacters)

        [PSCustomObject]@{
            PasswordAsString = $Password
            PasswordAsSecureString = ($Password | ConvertTo-SecureString -AsPlainText -Force)
        }

    } catch {
        throw "Failed to generate a password: $_"
    }
}