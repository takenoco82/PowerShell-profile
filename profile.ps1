param(
    [switch]$NoRestoreHistory
)

#=============================================================================
# Global Variables {{{

# 履歴ファイル
$global:PS_HISTORY_FILE = Join-Path -Path (Split-Path -Path $PROFILE) -ChildPath "PS_History.xml"
# 保存するヒストリの件数
$global:PS_HISTORY_SIZE = 1000
# history系のコマンドを除外する
$global:PS_INCLUDE_HISTORY_COMMAND = $false
# 重複したコマンドを除外する
$global:PS_INCLUDE_DUPLICATE_COMMAND = $false

#}}}

#=============================================================================
# Functions {{{

function Reload-Profile { #{{{
    . $PROFILE.CurrentUserAllHosts -NoRestoreHistory
    . $PROFILE.CurrentUserCurrentHost
} #}}}

# https://stuncloud.wordpress.com/2014/12/05/powershell_save_and_load_command_history/
function Save-History { #{{{
    param(
        [switch]$IncludeHistoryCommand = $global:PS_INCLUDE_HISTORY_COMMAND
        ,[switch]$IncludeDuplicateCommand = $global:PS_INCLUDE_DUPLICATE_COMMAND
    )

    # 履歴ファイルに保存されているヒストリ
    $SavedHistories = @()
    if (Test-Path -Path $global:PS_HISTORY_FILE) {
        $SavedHistories = Import-Clixml -Path $global:PS_HISTORY_FILE

        # 履歴ファイルがあってもヒストリがないと $null になる
        if ($null -eq $SavedHistories) {
            $SavedHistories = @()
        }
    }

    # メモリ上のヒストリとの差分を抽出してマージする
    $CurrentHistories = Get-History
    $NewCommandLines = Compare-Object $SavedHistories $CurrentHistories -Property CommandLine | ?{ $_.SideIndicator -eq "=>" } | %{ $_.CommandLine }
    $NewHistories = $CurrentHistories | ?{ $NewCommandLines -contains $_.CommandLine }
    $TargetHistories = $SavedHistories + $NewHistories

    # history系のコマンドを除外する
    if (-not $IncludeHistoryCommand) {
        $TargetHistories = $TargetHistories | ?{ $_.CommandLine -inotmatch "^(.*-)?history" }
    }

    # 重複したコマンドを除外する
    if (-not $IncludeDuplicateCommand) {
        $TargetHistories = $TargetHistories | Sort-Object StartExecutionTime -Descending | Sort-Object -Unique CommandLine
    }

    # 履歴ファイルに保存する
    $TargetHistories | Sort-Object StartExecutionTime | Select-Object -Last $global:PS_HISTORY_SIZE | Export-Clixml -Path $global:PS_HISTORY_FILE
} #}}}

# http://bakemoji.hatenablog.jp/entry/2014/07/22/214230
function Restore-History { #{{{
    param(
        [string]$HistoryFile = $global:PS_HISTORY_FILE
        ,[switch]$Force
    )

    $HistoryCount = (Get-History).Count
    if ($Force) {
        $Executable = $true
    } elseif ($HistoryCount -eq 0) {
        $Executable = $true
    } else {
        # http://d.hatena.ne.jp/newpops/20061120/p2
        # 選択肢の作成
        $TypeName = "System.Management.Automation.Host.ChoiceDescription"
        $Yes = New-Object $TypeName("&Yes", "実行する")
        $No  = New-Object $TypeName("&No", "実行しない")

        # 選択肢コレクションの作成
        $Assembly= $Yes.GetType().AssemblyQualifiedName
        $Choices = New-Object "System.Collections.ObjectModel.Collection``1[[$Assembly]]"
        $Choices.Add($Yes)
        $Choices.Add($No)

        # 選択プロンプトの表示
        $Answer = $host.ui.PromptForChoice("<ヒストリの復元>", "ヒストリの復元を行うと、現在のヒストリはすべて削除されます。実行しますか？", $Choices, 1)

        $Executable = ($Answer -eq 0)
    }

    if ($Executable) {
        if (Test-Path -Path $HistoryFile) {
            Clear-History
            Import-Clixml -Path $HistoryFile | Add-History
        }
    }
} #}}}

function Search-History { #{{{
    param (
        [string[]]$Keywords
        ,[int64[]]$Id
        ,[switch]$IncludeHistoryCommand = $global:PS_INCLUDE_HISTORY_COMMAND
        ,[switch]$IncludeDuplicateCommand = $global:PS_INCLUDE_DUPLICATE_COMMAND
        ,[switch]$AscendingId
    )

    begin {
        # $Id を数値に変換する
        $IdInt64 = @()
        if ($null -ne $Id) {
            $IdInt64 = $Id | %{ $_ -as [int64] } | ?{ $_ -ne $null }
        }

        # $Id でフィルタする
        if ($IdInt64.Count -eq 0) {
            $TargetHistories = Get-History
        } else {
            $TargetHistories = Get-History -Id $IdInt64
        }

        # history系のコマンドを除外する
        if (-not $IncludeHistoryCommand) {
            $TargetHistories = $TargetHistories | ?{ $_.CommandLine -inotmatch "^(.*-)?history" }
        }
    }

    process {
        # $Keywords の内容でフィルタする
        foreach ($Keyword in $Keywords) {
            $TargetHistories = $TargetHistories | ?{ ($_.CommandLine + "`t" + $_.Id) -imatch $Keyword }
        }
    }

    end {
        # 重複したコマンドを除外する
        if (-not $IncludeDuplicateCommand) {
            $TargetHistories = $TargetHistories | Sort-Object StartExecutionTime -Descending | Sort-Object -Unique CommandLine
        }

        # ソートする
        if ($AscendingId) {
            return $TargetHistories = $TargetHistories | Sort-Object Id
        } else {
            return $TargetHistories = $TargetHistories | Sort-Object StartExecutionTime -Descending
        }
    }
} #}}}

#}}}

#=============================================================================
# Others {{{

# PowerShell終了時の処理を登録
# http://poshcode.org/2139
Register-EngineEvent ([System.Management.Automation.PsEngineEvent]::Exiting) -Action {
    Save-History
} | Out-Null

# 履歴を復元する
if (-not $NoRestoreHistory) {
    Restore-History
}

#}}}

# vim: expandtab softtabstop=4 shiftwidth=4 foldmethod=marker
