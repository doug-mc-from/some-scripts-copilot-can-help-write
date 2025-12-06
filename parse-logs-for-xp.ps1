# navigate to C:\Users\Public\Daybreak Game Company\Installed Games\EverQuest and find all files matching eqlog_*.txt
$logDirectory = "C:\Users\Public\Daybreak Game Company\Installed Games\EverQuest"
$logFiles = Get-ChildItem -Path $logDirectory -Filter "eqlog_*.txt"

# start parsing the logs, matching on patterns:
# "you have entered" - indicates zone change
# Several lines indicating experience gain:
# [Sun Nov 02 01:35:51 2025] You gain party experience! (2.918%) - indicates experience gain at normal XP rate
# [Sat Oct 18 23:54:12 2025] You gain experience (with a bonus)! (5.800%) - indicates experience gain with an XP bonus
# [Fri Aug 29 18:21:27 2025] You gain party experience (with a bonus)! - old log that doesn't show xp gain, should be ignored.
# [Sun Nov 02 01:54:17 2025] You have gained a level! Welcome to level 15! - indicates level up, contains the new level for the character
# eqlog_Charname_server.txt - the character name and server can be extracted from the filename. Expect some fuzziness in that a timestamp
# may have been appended to filenames for the same character to avoid the performance impact of writing to overly large files.
# So getting a character's level may require checking multiple files for the same character on the same server. Which 
# means the files will need be be parsed in the order they were written to get the correct level for the character.

# overall goal:
# Identify the best zones for XP gain per hour for each character on each server.
# Output a summary of the amount of xp gain per zone per level.
# Ignore xp rates with a bonus, we only want base xp rates.
# We do not care about totals of xp gain, we only care about the xp gain from a single xp gain event. This will help identify the best zones for xp gain,
# regardless of how long the character spent in that zone in the past.

$xpData = @{}   

foreach ($logFile in $logFiles) {
    $fileName = $logFile.Name
    # Extract character name and server from filename
    if ($fileName -match "eqlog_(.+?)_(.+?)(_\d+)?\.txt") {
        $charName = $matches[1]
        $serverName = $matches[2]

        if (-not $xpData.ContainsKey($charName)) {
            $xpData[$charName] = @{}
        }
        if (-not $xpData[$charName].ContainsKey($serverName)) {
            $xpData[$charName][$serverName] = @{}
        }

        $currentZone = ""
        $currentLevel = 1

        $logLines = Get-Content -Path $logFile.FullName
        foreach ($line in $logLines) {
            # Check for zone change
            if ($line -match "you have entered (.+)") {
                $currentZone = $matches[1]
            }
            # Check for experience gain without bonus
            elseif ($line -match "You gain (party )?experience! \((\d+\.\d+)%\)") {
                $xpGain = [double]$matches[2]
                if (-not $xpData[$charName][$serverName].ContainsKey($currentZone)) {
                    $xpData[$charName][$serverName][$currentZone] = @{}
                }
                if (-not $xpData[$charName][$serverName][$currentZone].ContainsKey($currentLevel)) {
                    $xpData[$charName][$serverName][$currentZone][$currentLevel] = @()
                }
                $xpData[$charName][$serverName][$currentZone][$currentLevel] += $xpGain
            }
            # Check for level up
            elseif ($line -match "You have gained a level! Welcome to level (\d+)!") {
                $currentLevel = [int]$matches[1]
            }
        }
    }
}

# Output summary of xp amount from single kill at each level per zone per server. Ignore the character.
foreach ($charName in $xpData.Keys) {
    foreach ($serverName in $xpData[$charName].Keys) {
        Write-Output "Server: $serverName"
        foreach ($zone in $xpData[$charName][$serverName].Keys) {
            Write-Output "  Zone: $zone"
            foreach ($level in $xpData[$charName][$serverName][$zone].Keys) {
                $xpGains = $xpData[$charName][$serverName][$zone][$level]
                $averageXpGain = ($xpGains | Measure-Object -Average).Average
                Write-Output "    Level: $level - Average XP Gain per Event: $([math]::Round($averageXpGain, 3))%"
            }
        }
    }
}


