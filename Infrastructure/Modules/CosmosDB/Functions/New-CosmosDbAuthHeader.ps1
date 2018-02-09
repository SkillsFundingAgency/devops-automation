function New-CosmosDbAuthHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Verb,
        [Parameter(Mandatory = $true)]
        $ResourceType,
        [Parameter()]
        $ResourceId = "",
        [Parameter(Mandatory = $true)]
        $Key,
        [Parameter()]
        $TokenType = "master",
        [Parameter()]
        $TokenVersion = "1.0"

    )

    Add-Type @"
    using System;
    public class TokenGenerator
    {
        public string GenerateAuthToken(string verb, string resourceType, string resourceId, string date, string key, string keyType, string tokenVersion)
        {
            var hmacSha256 = new System.Security.Cryptography.HMACSHA256 { Key = Convert.FromBase64String(key) };

            verb = verb ?? "";
            resourceType = resourceType ?? "";
            resourceId = resourceId ?? "";

            string payLoad = string.Format(System.Globalization.CultureInfo.InvariantCulture, "{0}\n{1}\n{2}\n{3}\n{4}\n",
                    verb.ToLowerInvariant(),
                    resourceType.ToLowerInvariant(),
                    resourceId,
                    date.ToLowerInvariant(),
                    ""
            );

            byte[] hashPayLoad = hmacSha256.ComputeHash(System.Text.Encoding.UTF8.GetBytes(payLoad));
            string signature = Convert.ToBase64String(hashPayLoad);

            return System.Net.WebUtility.UrlEncode(String.Format(System.Globalization.CultureInfo.InvariantCulture, "type={0}&ver={1}&sig={2}",
                keyType,
                tokenVersion,
                signature));
        }
    }
"@

    $TokenGenerator = New-Object TokenGenerator

    return $TokenGenerator.GenerateAuthToken($Verb, $ResourceType, $ResourceId, [System.DateTime]::UtcNow.ToString("R"), $Key, $TokenType, $TokenVersion)
}
