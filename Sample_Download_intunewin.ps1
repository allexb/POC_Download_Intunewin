Install-Module -Name "IntuneWin32App"
$AppDisplayName = "Google Chrome 88.0.4324.150 x86"
$OutputFolder = "C:\temp\"
Connect-MSIntuneGraph -TenantName "yourtenant.onmicrosoft.com"
Write-Host "Application Name: "$AppDisplayName
function Test-IntuneGraphRequest {
    <#
    .SYNOPSIS
        Test if a certain resource is available in Intune Graph API.
 
    .DESCRIPTION
        Test if a certain resource is available in Intune Graph API.
 
    .NOTES
        Author: Nickolaj Andersen
        Contact: @NickolajA
        Created: 2020-01-04
        Updated: 2020-01-04
 
        Version history:
        1.0.0 - (2020-01-04) Function created
    #>
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("Beta", "v1.0")]
        [string]$APIVersion,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Resource
    )
    try {
        # Construct full URI
        $GraphURI = "https://graph.microsoft.com/$($APIVersion)/deviceAppManagement/$($Resource)"

        # Call Graph API and get JSON response
        $GraphResponse = Invoke-RestMethod -Uri $GraphURI -Headers $AuthToken -Method "GET" -ErrorAction Stop -Verbose:$false
        if ($GraphResponse -ne $null) {
            return $true
        }
    }
    catch [System.Exception] {
        return $false
    }
}

function Get-ErrorResponseBody {
        param(   
            [parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [System.Exception]$Exception
        )

        # Read the error stream
        $ErrorResponseStream = $Exception.Response.GetResponseStream()
        $StreamReader = New-Object System.IO.StreamReader($ErrorResponseStream)
        $StreamReader.BaseStream.Position = 0
        $StreamReader.DiscardBufferedData()
        $ResponseBody = $StreamReader.ReadToEnd()

        # Handle return object
        return $ResponseBody
    }


function Invoke-IntuneGraphRequest {
        param(   
            [parameter(Mandatory = $true, ParameterSetName = "Get")]
            [parameter(ParameterSetName = "Patch")]
            [ValidateNotNullOrEmpty()]
            [string]$URI,

            [parameter(Mandatory = $true, ParameterSetName = "Patch")]
            [ValidateNotNullOrEmpty()]
            [System.Object]$Body
        )
        try {
            # Construct array list for return values
            $ResponseList = New-Object -TypeName System.Collections.ArrayList

            # Call Graph API and get JSON response
            switch ($PSCmdlet.ParameterSetName) {
                "Get" {
                    Write-Verbose -Message "Current Graph API call is using method: Get"
                    $GraphResponse = Invoke-RestMethod -Uri $URI -Headers $AuthToken -Method Get -ErrorAction Stop -Verbose:$false
                    if ($GraphResponse -ne $null) {
                        if ($GraphResponse.value -ne $null) {
                            foreach ($Response in $GraphResponse.value) {
                                $ResponseList.Add($Response) | Out-Null
                            }
                        }
                        else {
                            $ResponseList.Add($GraphResponse) | Out-Null
                        }
                    }
                }
                "Patch" {
                    Write-Verbose -Message "Current Graph API call is using method: Patch"
                    $GraphResponse = Invoke-RestMethod -Uri $URI -Headers $AuthToken -Method Patch -Body $Body -ContentType "application/json" -ErrorAction Stop -Verbose:$false
                    if ($GraphResponse -ne $null) {
                        foreach ($ResponseItem in $GraphResponse) {
                            $ResponseList.Add($ResponseItem) | Out-Null
                        }
                    }
                    else {
                        Write-Warning -Message "Response was null..."
                    }
                }
            }

            return $ResponseList
        }
        catch [System.Exception] {
            # Construct stream reader for reading the response body from API call
            $ResponseBody = Get-ErrorResponseBody -Exception $_.Exception
    
            # Handle response output and error message
            Write-Output -InputObject "Response content:`n$ResponseBody"
            Write-Warning -Message "Request to $($URI) failed with HTTP Status $($_.Exception.Response.StatusCode) and description: $($_.Exception.Response.StatusDescription)"
        }
    }


$GraphVersion = "beta"
$App = Get-IntuneWin32App -DisplayName $AppDisplayName -Verbose
$ID  = $App.id
$GraphResource = "deviceAppManagement/mobileApps/$($ID)/microsoft.graph.win32LobApp/contentVersions"
$GraphURI = "https://graph.microsoft.com/$($GraphVersion)/$($GraphResource)"
#(Invoke-IntuneGraphRequest -APIVersion "Beta" -Resource "mobileApps/53056c77-2450-49f1-8b61-c0ea57adfa3e/microsoft.graph.win32LobApp/contentVersions" -Method "GET").value
$Win32AppContentVersions = Invoke-IntuneGraphRequest -URI $GraphURI




                
                $Win32AppContentVersionsFiles = (Invoke-IntuneGraphRequest -URI "https://graph.microsoft.com/$($GraphVersion)/deviceAppManagement/mobileApps/$($ID)/microsoft.graph.win32LobApp/contentVersions/$($Win32AppContentVersionID)/files")
                if ($Win32AppContentVersionsFiles -ne $null) {
                    foreach ($Win32AppContentVersionsFile in $Win32AppContentVersionsFiles) {
                         $ValidateContentVersionsFile = Test-IntuneGraphRequest -APIVersion $GraphVersion -Resource "mobileApps/$($ID)/microsoft.graph.win32LobApp/contentVersions/$($Win32AppContentVersionID)/files/$($Win32AppContentVersionsFile.id)"
                        if ($ValidateContentVersionsFile -eq $true) {
                            $Win32AppContentVersionsFileResource = Invoke-IntuneGraphRequest -URI "https://graph.microsoft.com/$($GraphVersion)/deviceAppManagement/mobileApps/$($ID)/microsoft.graph.win32LobApp/contentVersions/$($Win32AppContentVersionID)/files/$($Win32AppContentVersionsFile.id)"
                            if ($Win32AppContentVersionsFileResource -ne $null) {
                                # Start download of .intunewin content file
                                Write-Host "Attempting to download '$($Win32AppContentVersionsFileResource.name)' from: $($Win32AppContentVersionsFileResource.azureStorageUri)"
                                #Start-DownloadFile -URL $Win32AppContentVersionsFileResource.azureStorageUri -Destination "C:\temp\$Win32AppContentVersionsFileResource.name"
                                (New-Object System.Net.WebClient).DownloadFile($Win32AppContentVersionsFileResource.azureStorageUri, "$($OutputFolder)\$($Win32AppContentVersionsFileResource.name)")
                                If (test-path -Path "$($OutputFolder)\$($Win32AppContentVersionsFileResource.name)") 
                                {Write-Host "Downloaded: $($OutputFolder)$($Win32AppContentVersionsFileResource.name)"}
                                Else {Write-Host "Error downloading"}
                            }
                        }
                    }
                }
