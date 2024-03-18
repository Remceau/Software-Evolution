# INPUT
$INPUT_PATH = './openlibrary'
$START_DATE = Get-Date '2007-05-01'
$SCC_DIR = ''



# ====================== #
# START APPLICATION CODE #
# ====================== #
 
$CurrentDate = Get-Date
For ($Date = $START_DATE; $Date -lt $CurrentDate; $Date = $Date.AddMonths(1)) {
    # Search for earliest commit
    $StartDate = $Date.AddDays(-1);
    $EndDate = $StartDate.AddMonths(1);
    $Commits = wsl --cd (Get-Item $INPUT_PATH).FullName --exec git log --after="$StartDate" --until="$EndDate" --pretty=format:"%ad %h %s" --date=iso master | Sort-Object

    # Checkout as commit
    $Commit = $Commits[0]
    wsl --cd (Get-Item $INPUT_PATH).FullName --exec git checkout -f -q $Commit.Split(' ')[3]
    
    # Gather data
    $Data = wsl --cd (Get-Item $INPUT_PATH).FullName --exec $SCC_DIR/scc --format csv | ConvertFrom-Csv
    $Python = $Data | Where-Object Language -eq 'Python'
    $Javascript = $Data | Where-Object Language -eq 'Javascript'
    $HTML = $Data | Where-Object Language -eq 'HTML'

    # Return data
    $Month = $Date.ToString("yyyy-MM");
    Write-Host  $Month $Python.Lines $Javascript.Lines $HTML.Lines $Python.Code $Javascript.Code $HTML.Code $Python.Comments $Javascript.Comments $HTML.Comments
}
