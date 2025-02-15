function ConvertTo-Params {
  <#
  .SYNOPSIS
    Converts command-line arguments into type-safe parameters
  .DESCRIPTION
    Converts a string array of command-line arguments and parses them according to the parameter schema.
    Returns a generic dictionary containing the parsed values.
  .OUTPUTS
    System.Collections.Generic.Dictionary[string,ParamBase]
  .EXAMPLE
    $line = '--verbose -t 30 --retry=5 --output=log.txt --include=*.txt *.csv'
    $list = $line -split ' '

    ConvertTo-Params $list @(
      ('verbose', [switch], $false),
      ('t', [int], 0),
      ('retry', [int], 3),
      ('output', [string], 'output.log'),
      ('include', [string[]], @())
    )
  #>
  [CmdletBinding()]
  [OutputType([System.Collections.Generic.Dictionary[string, ParamBase]])]
  param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string[]]$list,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateNotNullOrEmpty()][Alias('ref')]
    [Object[]]$reference
  )
  process {
    try {
      $result = ([ArgParser][ParamSchema]$reference).Parse($list)
    } catch {
      $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ParseException]::new('Failed to parse arguments', $_))
    }
  }

  end {
    return $result
  }
}