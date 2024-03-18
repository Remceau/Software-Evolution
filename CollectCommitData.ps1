# INPUT
$INPUT_PATH = './openlibrary'
$OUTPUT_PATH = './CommitsDaily.csv'
$USE_WSL = $True

# OUTPUT
$Result = @{}



# ====================== #
# START APPLICATION CODE #
# ====================== #

# COLLECT COMMITS
If ($USE_WSL) {
    $Commits = wsl --cd (Get-Item $INPUT_PATH).FullName --exec git log --all --reflog --format='%cI'
} Else {
    Push-Location $INPUT_PATH
    $Commits = git --log --all --reflog --format='%cI'
    Pop-Location
}

# PARSE DATA
Foreach ($Commit in $Commits) {
    $Date = (Get-Date $Commit).ToString("yyyy-MM-dd")
    If (-not $Result.ContainsKey($Date)) {
        $Result[$Date] = New-Object PSObject -Property @{
            Date = $Date;
            Commits = 1;
        }
    } Else {
        $Result[$Date].Commits += 1
    }
}

# EXPORT DATA
$Result.Values | Sort-Object -Property Date | Export-Csv -Path $OUTPUT_PATH