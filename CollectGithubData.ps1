# INPUT
$APPLICATION_NAME = ''
$AUTHORIZATION_KEY = ''
$OUTPUT_PATH = './IssuesDaily.csv'
$VERBOSE_OUTPUT = $true

# OUTPUT
$Result = @{}



# ====================== #
# START CUSTOM FUNCTIONS #
# ====================== #
function Start-RateLimitSleep {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [Int] $Epoch
    )

    Write-Warning '  RATE LIMIT EXHAUSTED!'

    $RateLimitReset = [Datetime]::SpecifyKind('1970-01-01 00:00:00', [DateTimeKind]::Utc).AddSeconds($Epoch).ToUniversalTime()
    Write-Warning "    Rate limit will reset at $RateLimitReset UTC."

    For () {
        $CurrentTime = (Get-Date).ToUniversalTime()
        $WaitTill = New-TimeSpan -Start $CurrentTime -End $RateLimitReset

        If ($WaitTill.TotalSeconds -lt 0) {
            Write-Warning '    Rate limit should have been reset!'
            Break
        }
        
        Write-Warning "    Will sleep for $($WaitTill.TotalSeconds + 5) seconds."
        Start-Sleep -Seconds ($WaitTill.TotalSeconds + 5)
    }
}



# ====================== #
# START APPLICATION CODE #
# ====================== #

# SET LOG LEVEL
if ($VERBOSE_OUTPUT) {
    $VerbosePreference = 'Continue'
}

# PREPARE HEADERS
$Headers = @{
    'Accept'                = 'application/vnd.github+json';
    'X-Github-Api-Version'  = '2022-11-28';
    'User-Agent'            = $APPLICATION_NAME
    'Authorization'         = $AUTHORIZATION_KEY
}

# COLLECT ISSUES AND MERGE REQUESTS
Write-Verbose "COLLECTING REPOSITORY ISSUES"
$NextRequest = 'https://api.github.com/repos/internetarchive/openlibrary/issues?state=all&per_page=100'
For () {
    Write-Verbose "  Requesting content at $NextRequest."
    
    # SEND PAGINATED REQUEST
    if ($VERBOSE_OUTPUT) {
        $VerbosePreference = 'SilentlyContinue'
    }
    $Issues = Invoke-WebRequest -Headers $headers -Method Get -Uri $NextRequest
    if ($VERBOSE_OUTPUT) {
        $VerbosePreference = 'Continue'
    }
    
    # PARSE DATA
    Foreach ($Issue in ($Issues.Content | ConvertFrom-Json)) {

        # GET IMPORTANT TIMESTAMPS
        $CreatedAt = (Get-Date $Issue.created_at).ToString('yyyy-MM-dd')
        $ClosedAt = $null
        If (-not [string]::IsNullOrEmpty($Issue.closed_at)) {
            $ClosedAt = (Get-Date $Issue.closed_at).ToString('yyyy-MM-dd')
        }

        # POPULATE REQUIRED ENTRIES
        If (-not $Result.ContainsKey($CreatedAt)) {
            $Result[$CreatedAt] = New-Object PSObject -Property @{
                Date = $CreatedAt;
                IssuesCreated = 0;
                IssuesClosed = 0;
                PullRequestsCreated = 0;
                PullRequestsClosed = 0;
            }
        }
        if ($null -ne $ClosedAt -and -not $Result.ContainsKey($ClosedAt)) {
            $Result[$ClosedAt] = New-Object PSObject -Property @{
                Date = $ClosedAt;
                IssuesCreated = 0;
                IssuesClosed = 0;
                PullRequestsCreated = 0;
                PullRequestsClosed = 0;
            }
        }

        # UPDATE ENTRIES
        If ($null -ne $Issue.pull_request) {
            $Result[$CreatedAt].PullRequestsCreated += 1
            If ($null -ne $ClosedAt) {
                $Result[$ClosedAt].PullRequestsClosed += 1
            }
        } Else {
            $Result[$CreatedAt].IssuesCreated += 1
            If ($null -ne $ClosedAt) {
                $Result[$ClosedAt].IssuesClosed += 1
            }
        }
    }

    # HANDLE PAGINATION
    If ($Issues.Headers.Link -match '<([A-Za-z0-9:\/.?=_&]+)>;\s+rel="next"') {
        $NextRequest = $Matches[1]
    } Else {
        Break
    }

    # HANDLE RATE LIMIT
    If ($Issues.Headers['X-RateLimit-Remaining'] -le 0) {
        Start-RateLimitSleep -Epoch $Issues.Headers['X-RateLimit-Reset']
    }
}

# EXPORT DATA
$Result.Values | Sort-Object -Property Date | Export-Csv -Path $OUTPUT_PATH