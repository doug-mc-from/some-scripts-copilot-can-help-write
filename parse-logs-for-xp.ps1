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

$xpData = @{}
foreach ($logFile in $logFiles) {
    $fileName = $logFile.Name
    # Extract character name and server from filename
    if ($fileName -match "^eqlog_(.+?)_(.+?)(_\d{8}_\d{6})?\.txt$") {
        $charName = $matches[1]
        $serverName = $matches[2]

        # Initialize character data structure if not already present
        if (-not $xpData.ContainsKey($charName)) {
            $xpData[$charName] = @{
                Server = $serverName
                Levels = @{}
            }
        }

        $currentZone = ""
        $currentLevel = 1
        $zoneXpData = @{}

        # Read the log file line by line
        Get-Content -Path $logFile.FullName | ForEach-Object {
            $line = $_

            # Check for zone change
            if ($line -match "you have entered (.+)$") {
                $currentZone = $matches[1]
                if (-not $zoneXpData.ContainsKey($currentZone)) {
                    $zoneXpData[$currentZone] = @{
                        TotalXp = 0
                        Entries = 0
                    }
                }
            }

            # Check for experience gain without bonus
            if ($line -match "You gain (party )?experience! \((\d+\.\d+)%\)") {
                $xpPercent = [double]$matches[2]
                # Assuming a base XP value for calculation, e.g., 1000 XP per percent
                $baseXpValue = 1000
                $xpGained = $xpPercent * $baseXpValue / 100

                if ($currentZone -ne "") {
                    $zoneXpData[$currentZone].TotalXp += $xpGained
                    $zoneXpData[$currentZone].Entries += 1
                }
            }

            # Check for level up
            if ($line -match "You have gained a level! Welcome to level (\d+)!") {
                $currentLevel = [int]$matches[1]
            }
        }

        # Store zone XP data for the character at the current level
        foreach ($zone in $zoneXpData.Keys) {
            if (-not $xpData[$charName].Levels.ContainsKey($currentLevel)) {
                $xpData[$charName].Levels[$currentLevel] = @{}
            }
            if (-not $xpData[$charName].Levels[$currentLevel].ContainsKey($zone)) {
                $xpData[$charName].Levels[$currentLevel][$zone] = @{
                    TotalXp = 0
                    Entries = 0
                }
            }
            $xpData[$charName].Levels[$currentLevel][$zone].TotalXp += $zoneXpData[$zone].TotalXp
            $xpData[$charName].Levels[$currentLevel][$zone].Entries += $zoneXpData[$zone].Entries
        }
    }
}