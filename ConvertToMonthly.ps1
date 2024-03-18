$Result = @{}

$Days = Import-Csv -Path './IssuesDaily.csv'
Foreach ($Day in $Days) {
    $Month = (Get-Date $Day.Date).ToString("yyyy-MM")
    If (-not $Result.ContainsKey($Month)) {
        $Result[$Month] = New-Object PSObject -Property @{
            Date = $Month;
            IssuesCreated = 0;
            IssuesClosed = 0;
            PullRequestsCreated = 0;
            PullRequestsClosed = 0;
            Commits = 0;
        }
    }
    $Result[$Month].IssuesCreated += $Day.IssuesCreated
    $Result[$Month].IssuesClosed += $Day.IssuesClosed
    $Result[$Month].PullRequestsCreated += $Day.PullRequestsCreated
    $Result[$Month].PullRequestsClosed += $Day.PullRequestsClosed
}


$Days = Import-Csv -Path './CommitsDaily.csv'
Foreach ($Day in $Days) {
    $Month = (Get-Date $Day.Date).ToString("yyyy-MM")
    If (-not $Result.ContainsKey($Month)) {
        $Result[$Month] = New-Object PSObject -Property @{
            Date = $Month;
            IssuesCreated = 0;
            IssuesClosed = 0;
            PullRequestsCreated = 0;
            PullRequestsClosed = 0;
            Commits = 1;
        }
    }
    $Result[$Month].Commits += $Day.Commits
}
$Result.Values | Sort-Object -Property Date | Select-Object Date, Commits, IssuesCreated, IssuesClosed, PullRequestsCreated, PullRequestsClosed | Export-Csv -Path './Monthly.csv'