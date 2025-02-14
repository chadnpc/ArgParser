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
    $line = '--format=gnu -f --quoting-style=escape --rmt-command=/usr/lib/tar/rmt -delete-key=2 --filter name1 name2'
    $list = $line.Split(' ')
    $parsed_args = $list | ConvertTo-Params -array @(
      ('f', [switch], $false),
      ('format', [string], $false),
      ('rmt-command', [String], ''),
      ('quoting-style', [String], ''),
      ('delete-key', [bool], $true),
      ('filter', [String[]], $null)
    )
  #>
  [CmdletBinding(DefaultParameterSetName = 'array')]
  [OutputType([System.Collections.Generic.Dictionary[string, ParamBase]])]
  param (
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$argvr,

    [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'array')]
    [ValidateNotNullOrEmpty()][Alias('ref')]
    [Object[]]$reference,

    [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'schema')]
    [ValidateNotNullOrEmpty()]
    [ParamSchema]$schema
  )

  process {
    $schema = ($PSCmdlet.ParameterSetName -eq 'array') ? [ParamSchema]$reference : $schema
    $parser = [ArgParser]::new($schema)
    try {
      $result = $parser.Parse($argvr)
    } catch {
      $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ParseException]::new('Failed to parse arguments', $_))
    }
  }

  end {
    return $result
  }
}