# プロファイルのディレクトリ
$PROFILE_DIR = Split-Path -Path $PROFILE
# 履歴ファイル
$PS_HISTORY_FILE = Join-Path -Path $PROFILE_DIR -ChildPath "PS_History.xml"

#=============================================================================
# Functions {{{

function Reload-Profile { #{{{
    . $PROFILE.CurrentUserAllHosts
    . $PROFILE.CurrentUserCurrentHost
} #}}}

function Save-History { #{{{
    param(
        [switch]$NoSaveHistoryCommand # history系のコマンドを保存しない
        ,[switch]$IgnoreDuplicates    # 重複したコマンドを保存しない
    )

    # 履歴ファイルに保存されているヒストリ
    $SavedHistories = @()
    if (Test-Path -Path $PS_HISTORY_FILE) {
        $SavedHistories = Import-Clixml -Path $PS_HISTORY_FILE
    }

    # メモリ上のヒストリとマージして、history系のコマンドを除外する
    $TargetHistories = $SavedHistories + (Get-History) | ?{ !($NoSaveHistoryCommand) -or ($_.CommandLine -inotmatch "^(.*-)?history") }

    # 重複したコマンドを除外する
    if ($IgnoreDuplicates) {
        $TargetHistories = $TargetHistories | Sort-Object -Descending StartExecutionTime | Sort-Object -Unique CommandLine
    }

    # 履歴ファイルに保存する
    $TargetHistories | Sort-Object StartExecutionTime | Export-Clixml -Path $PS_HISTORY_FILE
} #}}}

# http://bakemoji.hatenablog.jp/entry/2014/07/22/214230
function Restore-History { #{{{
    if (Test-Path -Path $PS_HISTORY_FILE) {
        Import-Clixml -Path $PS_HISTORY_FILE | Add-History
    }
} #}}}

function Search-History { #{{{
    param (
        [string[]]$Keywords,
        [int64[]]$Id
    )

    begin {
        # $Id を数値に変換する
        $IdInt64 = @()
        if ($null -ne $Id) {
            $IdInt64 = $Id | %{ $_ -as [int64] } | ?{ $_ -ne $null }
        }

        # history系のコマンドは除外する
        if ($IdInt64.Count -eq 0) {
            $Histories = Get-History | ?{ $_.CommandLine -inotmatch "^(.*-)?history" }
        } else {
            $Histories = Get-History -Id $IdInt64 | ?{ $_.CommandLine -inotmatch "^(.*-)?history" }
        }
    }

    process {
        # $Keywords の内容でフィルタする
        foreach ($Keyword in $Keywords) {
            $Histories = $Histories | ?{ ($_.CommandLine + "`t" + $_.Id) -imatch $Keyword }
        }
    }

    end {
        # 重複したコマンドを除外して、新しいコマンドが先頭にくるようにソートする
        return $Histories | Sort-Object -Descending StartExecutionTime | Sort-Object -Unique CommandLine | Sort-Object -Descending StartExecutionTime
    }
} #}}}

#}}}

# vim: expandtab softtabstop=4 shiftwidth=4 foldmethod=marker
