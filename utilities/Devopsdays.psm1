$Script:DevopsdaysWebRoot = '.'

<#
.SYNOPSIS
    Creates a new DevOpsDays event
.DESCRIPTION
    Creates files from templates that are used to define the event. The files
    created are intended to be consumed by Hugo.
.PARAMETER City
    Mandatory - Name of city where DevOpsDays event will be held
.PARAMETER Year
    Optional - Year that event will be held. Defaults to current year.
.PARAMETER TwitterHandle
    Optional - Handle of Twitter account for the event. Defaults to devopsdays.
    exits.
.PARAMETER WebRoot
    Optional - Directory containing the devopsdays-web repository.
.EXAMPLE
    Add-DevopsdaysEvent -City 'New York'
.EXAMPLE
    Add-DevopsdaysEvent -City 'New York' -Year 2029 -TwitterHandle 'devopsdaysny'
#>
function Add-DevopsdaysEvent {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$City,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Year=(Get-Date).Year,

        [Parameter()]
        [string]$TwitterHandle='devopsdays',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$WebRoot=$Script:DevopsdaysWebRoot
    )

    Begin { Test-DevopsdaysWebRoot -WebRoot $WebRoot -ErrorAction Stop | Out-Null }

    process {
        $event = New-Object PSObject
        $event | Add-Member -Type NoteProperty -Name Year -Value $Year
        $event | Add-Member -Type NoteProperty -Name City -Value $City
        $event | Add-Member -Type NoteProperty -Name Name -Value (To_UrlSlug $City)
        $event | Add-Member -Type NoteProperty -Name TwitterHandle -Value ([regex]::Replace($TwitterHandle, '^@', ''))

        $CitySlug = $event.Name
        $EventSlug = "$($event.Year)-$($CitySlug)"

        Get-Content "$($WebRoot)\utilities\examples\yyyy-city.yml" |
        ForEach-Object { $_ -creplace 'YYYY', $event.Year } |
        ForEach-Object { $_ -creplace 'City', $event.City } |
        ForEach-Object { $_ -creplace 'yourlocation', $event.City } |
        ForEach-Object { $_ -creplace 'yyyy-city', $EventSlug } |
        ForEach-Object { $_ -creplace 'city-year', "$($CitySlug)-$($event.Year)" } |
        Out-File "$($WebRoot)\data\events\$($EventSlug).yml"
        Write-Verbose "Created file $($WebRoot)\data\events\$($EventSlug).yml"

        $dirs = @(
            "$($WebRoot)\content\events\$($EventSlug)"
        )
        foreach ($dir in $dirs) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Verbose "Created directory $($dir)"
        }
        
        $HugoDate = Get-Date -format "yyyy-MM-ddTHH:mm:sszzz"
        $EventFiles = Get-ChildItem -Recurse "$($WebRoot)\utilities\examples\sample-event\*.md"
        foreach ($EventFile in $EventFiles) {
            # The draft = true in the frontmatter is what prevents the sample event from showing on the site
            Get-Content $EventFile.PSPath |
            ForEach-Object { $_ -replace 'draft = true', '' } |
            ForEach-Object { $_ -creplace 'YYYY-city', $EventSlug } |
            ForEach-Object { $_ -creplace 'devopsdaysyourcity', $event.TwitterHandle } |
            ForEach-Object { $_ -replace '2000-01-01T01:01:01-06:00', $HugoDate } |
            Out-File -Force "$($WebRoot)\content\events\$($EventSlug)\$($EventFile.Name)"
            Write-Verbose "Created file $($WebRoot)\content\events\$($EventSlug)\$($EventFile.Name)"
        }

        $event | Set_Type -TypeName 'Devopsdays.Event'
    }
}

<#
.SYNOPSIS
    Creates a new DevOpsDays speaker
.DESCRIPTION
    Creates files from templates that are used to define a speaker for an event.

.PARAMETER Event
    Mandatory - Event that speaker will be added to

.PARAMETER City
    Mandatory - Name of event city to add speaker to
.PARAMETER Year
    Mandatory - Year that event to add spearker to

.PARAMETER SpeakerName
    Name of speaker
.PARAMETER TwitterHandle
    Handle of Twitter account for the speaker.
.PARAMETER Bio
    A brief bio of the speaker
.PARAMETER Title
    Title of the speaker's talk
.PARAMETER Abstract
    Description of the speaker's talk

.PARAMETER WebRoot
    Directory containing the devopsdays-web repository.

.EXAMPLE
    Add-DevopsdaysSpeaker -City 'New York' -Year 2029 -SpeakerName 'Speaker Name' -TwitterHandle 'speakerhandle' -Bio 'bio' -Title 'Talk Title' -Abstract 'My abstract'
.EXAMPLE
    $event = Add-DevopsdaysEvent -City 'New York' -Year 2029
    Add-DevopsdaysSpeaker -Event $event -SpeakerName 'Speaker Name' -TwitterHandle 'speakerhandle' -Bio 'bio' -Title 'Talk Title' -Abstract 'My abstract'
.EXAMPLE
    Import-Csv 'speakers.csv' | Add-DevopsdaysSpeaker -City 'New York' -Year 2029

#>
function Add-DevopsdaysSpeaker {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,ParameterSetName="ByEvent")]
        [PSObject]$Event,

        [Parameter(Mandatory=$true,ParameterSetName="ByEventDetails")]
        [ValidateNotNullOrEmpty()]
        [string]$City,

        [Parameter(Mandatory=$true,ParameterSetName="ByEventDetails")]
        [ValidateNotNullOrEmpty()]
        [string]$Year,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]$SpeakerName,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]$TwitterHandle,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]$Bio,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]$Title,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]$Abstract,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$WebRoot=$Script:DevopsdaysWebRoot
    )

    Begin {
        Test-DevopsdaysWebRoot -WebRoot $WebRoot -ErrorAction Stop | Out-Null

        if ($Event -ne $null) {
            $City = $Event.City
            $Year = $Event.Year
        }

        $CitySlug = To_UrlSlug $City
        $EventSlug = "$($Year)-$($CitySlug)"
        $HugoDate = Get-Date -format "yyyy-MM-ddTHH:mm:sszzz"
    
        $dirs = @(
            "$($WebRoot)\content\events\$($EventSlug)\program"
            "$($WebRoot)\data\speakers\$($Year)\$($CitySlug)"
            "$($WebRoot)\static\events\$($EventSlug)\speakers"
        )
        foreach ($dir in $dirs) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Verbose "Created directory $($dir)"
        }
        
        # Create empty speakers file
        Get-Content "$($WebRoot)\utilities\examples\speakers\speakers.md" |
        ForEach-Object { $_ -replace '2000-01-01T01:01:01-06:00', $HugoDate } |
        Out-File "$($WebRoot)\content\events\$($EventSlug)\speakers.md"
        Write-Verbose "Created file $($WebRoot)\content\events\$($EventSlug)\speakers.md"
    }

    process {
        $speaker = New-Object PSObject
        $speaker | Add-Member -Type NoteProperty -Name Year -Value $Year
        $speaker | Add-Member -Type NoteProperty -Name City -Value $City
        $speaker | Add-Member -Type NoteProperty -Name SpeakerName -Value $SpeakerName
        $speaker | Add-Member -Type NoteProperty -Name TwitterHandle -Value ([regex]::Replace($TwitterHandle, '^@', ''))
        $speaker | Add-Member -Type NoteProperty -Name Bio -Value $Bio
        $speaker | Add-Member -Type NoteProperty -Name Title -Value $Title
        $speaker | Add-Member -Type NoteProperty -Name Abstract -Value $Abstract
        
        $SpeakerSlug = To_UrlSlug $speaker.SpeakerName

        # Populate speaker data file
        Get-Content "$($WebRoot)\utilities\examples\speakers\speaker-full-name.yml" |
        ForEach-Object { $_ -replace '2000-01-01T01:01:01-06:00', $HugoDate } |
        ForEach-Object { $_ -creplace 'SPEAKERNAME', $SpeakerName } |
        ForEach-Object { $_ -creplace 'SPEAKERTWITTER', $TwitterHandle } |
        ForEach-Object { $_ -creplace 'SPEAKERBIO', $Bio } |
        Out-File "$($WebRoot)\data\speakers\$($Year)\$($CitySlug)\$($SpeakerSlug).yml"
        Write-Verbose "Created file $($WebRoot)\data\speakers\$($Year)\$($CitySlug)\$($SpeakerSlug).yml"

        # Set default image
        Copy-Item -Path "$($WebRoot)\utilities\examples\speakers\speaker-full-name.jpg" -Destination "$($WebRoot)\static\events\$($EventSlug)\speakers\$($SpeakerSlug).jpg"
        Write-Verbose "Created file $($WebRoot)\static\events\$($EventSlug)\speakers\$($SpeakerSlug).jpg"

        # Populate talk file
        Get-Content "$($WebRoot)\utilities\examples\speakers\speaker-full-name.md" |
        ForEach-Object { $_ -replace '2000-01-01T01:01:01-06:00', $HugoDate } |
        ForEach-Object { $_ -creplace 'SPEAKERNAME', $SpeakerName } |
        ForEach-Object { $_ -creplace 'SPEAKERSLUG', $SpeakerSlug } |
        ForEach-Object { $_ -creplace 'TITLE', $Title } |
        ForEach-Object { $_ -creplace 'ABSTRACT', $Abstract } |
        Out-File "$($WebRoot)\content\events\$($EventSlug)\program\$($SpeakerSlug).md"
        Write-Verbose "Created file $($WebRoot)\content\events\$($EventSlug)\program\$($SpeakerSlug).md"

        $speaker | Set_Type -TypeName 'Devopsdays.Speaker'
    }
}

<#
.SYNOPSIS
    Creates a new DevOpsDays sponsor
.DESCRIPTION
    Creates files from templates that are used to define a sponsor for an event.

.PARAMETER Event
    Mandatory - Event that speaker will be added to

.PARAMETER City
    Mandatory - Name of event city to add speaker to
.PARAMETER Year
    Mandatory - Year that event to add spearker to

.PARAMETER SponsorName
    Name of sponsor
.PARAMETER SponsorUrl
    URL of sponsor
.PARAMETER Logo
    Path to a 200x200 PNG logo

.PARAMETER WebRoot
    Directory containing the devopsdays-web repository.

.EXAMPLE
    Add-DevopsdaysSponsor -City 'New York' -Year 2029 -SponsorName 'Sponsor Name' -SponsorUrl 'https://example.com' -Logo 'logo.png'
.EXAMPLE
    $event = Add-DevopsdaysEvent -City 'New York' -Year 2029
    Add-DevopsdaysSponsor -Event $event -SponsorName 'Sponsor Name' -SponsorUrl 'https://example.com' -Logo 'logo.png'
.EXAMPLE
    Import-Csv 'sponsors.csv' | Add-DevopsdaysSponsor -City 'New York' -Year 2029

#>
function Add-DevopsdaysSponsor {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,ParameterSetName="ByEvent")]
        [PSObject]$Event,

        [Parameter(Mandatory=$true,ParameterSetName="ByEventDetails")]
        [ValidateNotNullOrEmpty()]
        [string]$City,

        [Parameter(Mandatory=$true,ParameterSetName="ByEventDetails")]
        [ValidateNotNullOrEmpty()]
        [string]$Year,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]$SponsorName,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]$SponsorUrl,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$Logo,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$WebRoot=$Script:DevopsdaysWebRoot
    )

    Begin {
        Test-DevopsdaysWebRoot -WebRoot $WebRoot -ErrorAction Stop | Out-Null

        if ($Event -ne $null) {
            $City = $Event.City
            $Year = $Event.Year
        }

        $CitySlug = To_UrlSlug $City
        $EventSlug = "$($Year)-$($CitySlug)"
    }

    process {
        $sponsor = New-Object PSObject
        $sponsor | Add-Member -Type NoteProperty -Name Year -Value $Year
        $sponsor | Add-Member -Type NoteProperty -Name City -Value $City
        $sponsor | Add-Member -Type NoteProperty -Name SponsorName -Value $SponsorName
        $sponsor | Add-Member -Type NoteProperty -Name SponsorUrl -Value $SponsorUrl
        
        $SponsorSlug = To_UrlSlug $sponsor.SponsorName

        # Populate sponsor data file
        Get-Content "$($WebRoot)\utilities\examples\sponsor.yml" |
        ForEach-Object { $_ -creplace 'SPONSORNAME', $SponsorName } |
        ForEach-Object { $_ -creplace 'URL', $SponsorUrl } |
        Out-File "$($WebRoot)\data\sponsors\$($SponsorSlug).yml"
        Write-Verbose "Created file $($WebRoot)\data\sponsors\$($SponsorSlug).yml"

        # Set logo
        Copy-Item -Path $Logo -Destination "$($WebRoot)\static\img\sponsors\$($SponsorSlug).jpg"
        Write-Verbose "Created file $($WebRoot)\static\img\sponsors\$($SponsorSlug).jpg"

        Write-Host "Add this to ../data/events/$($EventSlug).yml under sponsors:"
        Write-Host "  - id: $($SponsorSlug)"
        Write-Host "    level: theirlevel"

        $sponsor | Set_Type -TypeName 'Devopsdays.Sponsor'
    }
}

<#
.SYNOPSIS
    Clears the default directory containing the devopsdays-web
    repository for this module
.DESCRIPTION
    The cmdlet clears a previously set directory containing the
    devopsdays-web repository for the cmdlets in this module.
.EXAMPLE
    Clear-DevopsdaysWebRoot
#>
function Clear-DevopsdaysWebRoot {
    Write-Verbose "Clearing `$script:DevopsdaysWebRoot"
    $Script:DevopsdaysWebRoot = '.'
}

<#
.SYNOPSIS
    Returns the default directory containing the devopsdays-web
    repository for this module
.DESCRIPTION
    The cmdlet returns previously defined path to the devopsdays-web
    repository.
    If it was never set or cleared, the function returns
    '.' (current directory)
.EXAMPLE
    Get-DevopsdaysWebRoot
#>
function Get-DevopsdaysWebRoot {
    $Script:DevopsdaysWebRoot
}

<#
.SYNOPSIS
    Sets the default directory containing the devopsdays-web
    repository for this module
.DESCRIPTION
    The cmdlet sets the default directory containing the
    devopsdays-web repository for all Devopsdays
    functions, so the user doesn't have to specify it all the time.
.PARAMETER WebRoot
    Mandatory - Path to the directory containing the
    devopsdays-web repository
.EXAMPLE
    Set-DevopsdaysWebRoot 'C:\dev\devopsdays-web'
#>
function Set-DevopsdaysWebRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$WebRoot
    )
    Test-DevopsdaysWebRoot -WebRoot $WebRoot | Out-Null

    Write-Verbose "Setting `$script:DevopsdaysWebRoot to $WebRoot"
    $Script:DevopsdaysWebRoot = Resolve-Path $WebRoot | Select-Object -ExpandProperty Path
}

<#
.SYNOPSIS
    Validates the default directory containing the devopsdays-web
    repository
.DESCRIPTION
    This cmdlet is used for a vague validation of the path to the
    directory that should contain the devopsdays-web repository.
.PARAMETER WebRoot
    Mandatory - Path to the directory containing the
    devopsdays-web repository
.EXAMPLE
    Test-DevopsdaysWebRoot 'C:\dev\devopsdays-web'
#>
function Test-DevopsdaysWebRoot {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param(
        [Parameter(Position=0)]
        [string]$WebRoot
    )

    try {
        $WebRoot = Resolve-Path $WebRoot | Select-Object -ExpandProperty Path

        Write-Verbose "Checking if path $WebRoot exists..."
        if (-Not (Test-Path -Path $WebRoot -ErrorAction Stop)) { throw }

        Write-Verbose "Testing if path contains config.toml file..."
        if (-Not (Test-Path -Path "$($WebRoot)\config.toml" -ErrorAction Stop)) { throw }

        Write-Verbose "Testing if config.toml contains 'DevOpsDays' string..."
        $content = Get-Content -Raw -Path "$($WebRoot)\config.toml" -ErrorAction Stop
        if ($content -inotmatch "DevOpsDays") { throw }

        return $true
    } catch {
        Write-Error "Please provide the path to the root of the devopsdays-web directory"
    }
    return $false
}

function Set_Type {
    param(
        [Parameter(ValueFromPipeline=$true)]
        [psobject[]]$InputObject,
        [string]$TypeName
    )
    process {
        foreach ($object in $InputObject) {
            if ($TypeName) {
                $object.psobject.TypeNames.Insert(0, $TypeName)
            }
            $object
        }
    }
}

function To_UrlSlug {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$InputString
    )

    process {
        $Slug = $InputString.Replace('-', ' ')
        $Slug = [regex]::Replace($Slug, '[^\w ]', '')
        $Slug = $Slug.ToLower()
        $Slug = [Text.Encoding]::ASCII.GetString([Text.Encoding]::GetEncoding('Cyrillic').GetBytes($Slug))
        $Slug = $Slug.Replace(' ', '-')
        $Slug
    }
}
