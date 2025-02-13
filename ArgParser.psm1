#!/usr/bin/env pwsh

#region    Classes
class ParamBase : System.Reflection.ParameterInfo {
  [bool]$IsDynamic
  [System.Object]$Value
  [System.Collections.ObjectModel.Collection[string]]$Aliases
  [System.Collections.ObjectModel.Collection[Attribute]]$Attributes
  [System.Collections.Generic.IEnumerable[System.Reflection.CustomAttributeData]]$CustomAttributes
  ParamBase([string]$Name) { [void]$this.Create($Name, [System.Management.Automation.SwitchParameter], $null) }
  ParamBase([string]$Name, [type]$Type) { [void]$this.Create($Name, $Type, $null) }
  ParamBase([string]$Name, [System.Object]$value) { [void]$this.Create($Name, ($value.PsObject.TypeNames[0] -as 'Type'), $value) }
  ParamBase([string]$Name, [type]$Type, [System.Object]$value) { [void]$this.create($Name, $Type, $value) }
  ParamBase([System.Management.Automation.ParameterMetadata]$ParameterMetadata, [System.Object]$value) { [void]$this.Create($ParameterMetadata, $value) }
  hidden [ParamBase] Create([string]$Name, [type]$Type, [System.Object]$value) { return $this.Create([System.Management.Automation.ParameterMetadata]::new($Name, $Type), $value) }
  hidden [ParamBase] Create([System.Management.Automation.ParameterMetadata]$ParameterMetadata, [System.Object]$value) {
    $Name = $ParameterMetadata.Name; if ([string]::IsNullOrWhiteSpace($ParameterMetadata.Name)) { throw [System.ArgumentNullException]::new('Name') }
    $PType = $ParameterMetadata.ParameterType; [ValidateNotNullOrEmpty()][type]$PType = $PType;
    if ($null -ne $value) {
      try {
        $this.Value = $value -as $PType;
      } catch {
        $InnrEx = [System.Exception]::new()
        $InnrEx = if ($null -ne $this.Value) { if ([Type]$this.Value.PsObject.TypeNames[0] -ne $PType) { [System.InvalidOperationException]::New('Operation is not valid due to ambigious parameter types') }else { $innrEx } } else { $innrEx }
        throw [System.Management.Automation.SetValueException]::new("Unable to set value for $($this.ToString()) parameter.", $InnrEx)
      }
    }; $this.Aliases = $ParameterMetadata.Aliases; $this.IsDynamic = $ParameterMetadata.IsDynamic; $this.Attributes = $ParameterMetadata.Attributes;
    $this.PsObject.properties.add([psscriptproperty]::new('Name', [scriptblock]::Create("return '$Name'"), { throw "'Name' is a ReadOnly property." }));
    $this.PsObject.properties.add([psscriptproperty]::new('IsSwitch', [scriptblock]::Create("return [bool]$([int]$ParameterMetadata.SwitchParameter)"), { throw "'IsSwitch' is a ReadOnly property." }));
    $this.PsObject.properties.add([psscriptproperty]::new('ParameterType', [scriptblock]::Create("return [Type]'$PType'"), { throw "'ParameterType' is a ReadOnly property." }));
    $this.PsObject.properties.add([psscriptproperty]::new('DefaultValue', [scriptblock]::Create('return $(switch ($this.ParameterType) { ([bool]) { $false } ([string]) { [string]::Empty } ([array]) { @() } ([hashtable]) { @{} } Default { $null } }) -as $this.ParameterType'), { throw "'DefaultValue' is a ReadOnly property." }));
    $this.PsObject.properties.add([psscriptproperty]::new('RawDefaultValue', [scriptblock]::Create('return $this.DefaultValue.ToString()'), { throw "'RawDefaultValue' is a ReadOnly property." }));
    $this.PsObject.properties.add([psscriptproperty]::new('HasDefaultValue', [scriptblock]::Create('return $($null -ne $this.DefaultValue)'), { throw "'HasDefaultValue' is a ReadOnly property." })); return $this
  }
  [string] ToString() { $nStr = if ($this.IsSwitch) { '[switch]' }else { '[Parameter()]' }; return ('{0}${1}' -f $nStr, $this.Name) }
}

class ArgParser {
  ArgParser() {}
  # The Parse method takes an array of command-line arguments and parses them according to the parameters specified using AddParameter.
  # returns a dictionary containing the parsed values.
  #
  # $stream = @('str', 'eam', 'mm'); $filter = @('ffffil', 'llll', 'tttr', 'rrr'); $excludestr = @('sss', 'ddd', 'ggg', 'hhh'); $dkey = [consolekey]::S
  # $cliArgs = '--format=gnu -f- -b20 --quoting-style=escape --rmt-command=/usr/lib/tar/rmt -DeleteKey [consolekey]$dkey -Exclude [string[]]$excludestr -Filter [string[]]$filter -Force -Include [string[]]$IncludeStr -Recurse -Stream [string[]]$stream -Confirm -WhatIf'.Split(' ')
  static [System.Collections.Generic.Dictionary[String, ParamBase]] Parse([string[]]$cliArgs, [System.Collections.Generic.Dictionary[String, ParamBase]]$ParamBaseDict) {
    [ValidateNotNullOrEmpty()]$cliArgs = $cliArgs; [ValidateNotNullOrEmpty()]$ParamBaseDict = $ParamBaseDict; $paramDict = [System.Collections.Generic.Dictionary[String, ParamBase]]::new()
    for ($i = 0; $i -lt $cliArgs.Count; $i++) {
      $arg = $cliArgs[$i]; ($name, $IsParam) = switch ($true) {
        $arg.StartsWith('--') { $arg.Substring(2), $true; break }
        $arg.StartsWith('-') { $arg.Substring(1), $true; break }
        Default { $arg; $false }
      }
      if ($IsParam) {
        $lgcp = $name.Contains('=')
        if ($lgcp) { $name = $name.Substring(0, $name.IndexOf('=')) }
        $bParam_Index = $ParamBaseDict.Keys.Where({ $_ -match $name })
        $IsKnownParam = $null -ne $bParam_Index; $Param = if ($IsKnownParam) { $ParamBaseDict[$name] } else { $null }
        $IsKnownParam = $null -ne $Param
        if ($IsKnownParam) {
          if (!$lgcp) {
            $i++; $argVal = $cliArgs[$i]
            if ($Param.ParameterType.IsArray) {
              $arr = [System.Collections.Generic.List[Object]]::new()
              while ($i -lt $cliArgs.Count -and !$cliArgs[$i].StartsWith('-')) {
                $arr.Add($argVal); $i++; $argVal = $cliArgs[$i]
              }
              $paramDict.Add($name, [ParamBase]::New($name, $Param.ParameterType, $($arr.ToArray() -as $Param.ParameterType)))
            } else {
              $paramDict.Add($name, [ParamBase]::New($name, $Param.ParameterType, $argVal))
            }
          } else {
            $i++; $argVal = $name.Substring($name.IndexOf('=') + 1)
            $paramDict.Add($name, [ParamBase]::New($name, $Param.ParameterType, $argVal))
          }
        } else { Write-Warning "[ArgParser] : Unknown parameter: $name" }
      }
    }
    return $paramDict
  }
  static [System.Collections.Generic.Dictionary[String, ParamBase]] Parse([string[]]$cliArgs, [System.Collections.Generic.Dictionary[System.Management.Automation.ParameterMetadata, object]]$ParamBase) {
    $ParamBaseDict = [System.Collections.Generic.Dictionary[String, ParamBase]]::New(); $ParamBase.Keys | ForEach-Object { $ParamBaseDict.Add($_.Name, [ParamBase]::new($_.Name, $_.ParameterType, $ParamBase[$_])) }
    return [ArgParser]::Parse($cliArgs, $ParamBaseDict)
  }
  # A method to convert parameter names from their command-line format (using dashes) to their property name format (using PascalCase).
  static hidden [string] MungeName([string]$name) {
    return [string]::Join('', ($name.Split('-') | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }))
  }
}
#endregion Classes
# Types that will be available to users when they import the module.
$typestoExport = @(
  [ArgParser], [ParamBase]
)
$TypeAcceleratorsClass = [PsObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
foreach ($Type in $typestoExport) {
  if ($Type.FullName -in $TypeAcceleratorsClass::Get.Keys) {
    $Message = @(
      "Unable to register type accelerator '$($Type.FullName)'"
      'Accelerator already exists.'
    ) -join ' - '

    [System.Management.Automation.ErrorRecord]::new(
      [System.InvalidOperationException]::new($Message),
      'TypeAcceleratorAlreadyExists',
      [System.Management.Automation.ErrorCategory]::InvalidOperation,
      $Type.FullName
    ) | Write-Warning
  }
}
# Add type accelerators for every exportable type.
foreach ($Type in $typestoExport) {
  $TypeAcceleratorsClass::Add($Type.FullName, $Type)
}
# Remove type accelerators when the module is removed.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
  foreach ($Type in $typestoExport) {
    $TypeAcceleratorsClass::Remove($Type.FullName)
  }
}.GetNewClosure();

$scripts = @();
$Public = Get-ChildItem "$PSScriptRoot/Public" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
$scripts += Get-ChildItem "$PSScriptRoot/Private" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
$scripts += $Public

foreach ($file in $scripts) {
  Try {
    if ([string]::IsNullOrWhiteSpace($file.fullname)) { continue }
    . "$($file.fullname)"
  } Catch {
    Write-Warning "Failed to import function $($file.BaseName): $_"
    $host.UI.WriteErrorLine($_)
  }
}

$Param = @{
  Function = $Public.BaseName
  Cmdlet   = '*'
  Alias    = '*'
  Verbose  = $false
}
Export-ModuleMember @Param
