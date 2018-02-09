foreach ($Publicfunction in Get-ChildItem -Path "$($PSScriptRoot)\Functions\*.ps1" -Recurse -Verbose:$VerbosePreference) {
    . $PublicFunction.FullName

    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($PublicFunction)

    Export-ModuleMember -Function ($BaseName)
}
