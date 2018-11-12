function BlobCopy {
    <#
.SYNOPSIS
Copy content to blob storage and update ContentType(MIME) settings

.DESCRIPTION
Copy content to blob storage and update ContentType(MIME) settings using AzCopy
AzCopy syntax: https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy

.PARAMETER Source
The source location of the files to be copied

.PARAMETER Destination
The blob destinaton of where to copy the files

.PARAMETER SaSToken
The SaS Token to access the blob storage container

.EXAMPLE

$BlobCopyParameters = @ {
    Source = "c:\FilesToBeCopied\"
    Destination = "https://name.blob.core.windows.net/cdn"
    SaSToken = "MySecureSaStokenString"

}
BlobCopy @BlobCopyParameters

#>
    Param(
        [Parameter(Mandatory = $true)]
        [String]$Source,
        [Parameter(Mandatory = $true)]
        [String]$Destination,
        [Parameter(Mandatory = $true)]
        [String]$SaSToken
    )

    try {
        # --- Set location for AzCopy.exe
        Write-Log -LogLevel Information -Message "setting location to AzCopy.exe..."
        Set-location -path "$PSScriptRoot\..\AzCopy\"

        Write-Log -LogLevel Information -Message "Invoking AzCopy to upload content and change MIME settings..."
        # ---> Invoke AzCopy.exe for
        .\AzCopy.exe /Source:$Source /Dest:$Destination /DestKey:$SaStoken /NC:10 /Z /V /S /Y /SetContentType
        # ---> Invoke AzCopy.exe for *.woff
        .\AzCopy.exe /Source:$Source /Dest:$Destination /DestKey:$SaStoken /NC:10 /Z /V /Pattern:"*.woff" /SetContentType:"application/font-woff" /S /Y
        # ---> Invoke AzCopy.exe for *.woff2
        .\AzCopy.exe /Source:$Source /Dest:$Destination /DestKey:$SaStoken /NC:10 /Z /V /Pattern:"*.woff2" /SetContentType:"application/font-woff2" /S /Y

    }
    catch {
        throw "Failed to copy content to blob and set MIME settings: $_"
    }
}
