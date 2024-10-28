oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/powerlevel10k_rainbow.omp.json" | Invoke-Expression

# PowerShell parameter completion shim for the Rush CLI
Register-ArgumentCompleter -Native -CommandName rush -ScriptBlock {
  param($commandName, $commandAst, $cursorPosition)
    [string]$value = $commandAst.ToString()
    # Handle input like `rush install; rush bui` + Tab
    [int]$position = [Math]::Min($cursorPosition, $value.Length)

    rush tab-complete --position $position --word "$value" | ForEach-Object {
      [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
 }
