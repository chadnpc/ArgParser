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

    # Using a reference object:

    ConvertTo-Params $list @(
      ('verbose', [switch], $false),
      ('t', [int], 0),
      ('retry', [int], 3),
      ('output', [string], 'output.log'),
      ('include', [string[]], @())
    )
    .EXAMPLE
    # If a reference object is seems ugly to use, here's a more elegant way ..Hashmaps ☻ :

    ConvertTo-Params $list -s @{
      verbose = [switch], $false
      t       = [int], 0
      retry   = [int], 3
      output  = [string], 'output.log'
      include = [string[]], @()
    }

    .NOTES
    This function works best with command-line arguments that have '=' signs. ex: --keys=value1 value2  (not: --keys value1 value2)
    -ie: Spaces separated args work, but not always, so just use '=' to be safe.
  #>
  [CmdletBinding(DefaultParameterSetName = 'schema')]
  [OutputType([System.Collections.Generic.Dictionary[string, ParamBase]])]
  param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()][Alias('l')]
    [string[]]$list,

    [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'schema')]
    [ValidateNotNullOrEmpty()][Alias('s')]
    [hashtable]$schema,

    [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'reference')]
    [ValidateNotNullOrEmpty()][Alias('r')]
    [Object[]]$reference
  )
  process {
    try {
      $parser = [argparser][ParamSchema](($pscmdlet.ParameterSetName -eq 'schema') ? $schema : $reference)
      $result = $parser.Parse($list)
    } catch {
      $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ParseException]::new('🛑 Failed to parse arguments', $_.Exception))
    }
  }

  end {
    return $result
  }
}
