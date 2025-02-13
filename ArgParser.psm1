using namespace System.Reflection
using namespace System.Collections.Generic
using namespace System.Collections.ObjectModel
#!/usr/bin/env pwsh

#region    Classes

class ParamBase : ParameterInfo {
  [bool]$IsDynamic
  [System.Object]$Value
  [Collection[string]]$Aliases
  [Collection[Attribute]]$Attributes
  [IEnumerable[CustomAttributeData]]$CustomAttributes

  ParamBase([string]$Name) {
    [void][ParamBase]::From($Name, [System.Management.Automation.SwitchParameter], $null, [ref]$this)
  }
  ParamBase([Object[]]$array) {
    [void][ParamBase]::From([string]$array[0], [type]$array[1], [System.Object]$array[2], [ref]$this)
  }
  ParamBase([string]$Name, [type]$Type) {
    [void][ParamBase]::From($Name, $Type, $null, [ref]$this)
  }
  ParamBase([string]$Name, [System.Object]$value) {
    [void][ParamBase]::From($Name, ($value.PsObject.TypeNames[0] -as 'Type'), $value, [ref]$this)
  }
  ParamBase([string]$Name, [type]$Type, [System.Object]$value) {
    [void][ParamBase]::From($Name, $Type, $value, [ref]$this)
  }
  ParamBase([System.Management.Automation.ParameterMetadata]$ParameterMetadata, [System.Object]$value) {
    [void][ParamBase]::From($ParameterMetadata, $value, [ref]$this)
  }

  static hidden [ParamBase] From([string]$Name, [type]$Type, [System.Object]$value, [ref]$ref) {
    return [ParamBase]::From([System.Management.Automation.ParameterMetadata]::new($Name, $Type), $value, $ref)
  }
  static hidden [ParamBase] From([System.Management.Automation.ParameterMetadata]$ParameterMetadata, [System.Object]$value, [ref]$ref) {
    $Name = $ParameterMetadata.Name; if ([string]::IsNullOrWhiteSpace($ParameterMetadata.Name)) { throw [System.ArgumentNullException]::new('Name') }
    $PType = $ParameterMetadata.ParameterType; [ValidateNotNullOrEmpty()][type]$PType = $PType;
    if ($null -ne $value) {
      try {
        $ref.Value.Value = $value -as $PType;
      } catch {
        $InnrEx = [System.Exception]::new()
        $InnrEx = if ($null -ne $ref.Value.Value) { if ([Type]$ref.Value.Value.PsObject.TypeNames[0] -ne $PType) { [System.InvalidOperationException]::New('Operation is not valid due to ambigious parameter types') }else { $innrEx } } else { $innrEx }
        throw [System.Management.Automation.SetValueException]::new("Unable to set value for $($ref.Value.ToString()) parameter.", $InnrEx)
      }
    }; $ref.Value.Aliases = $ParameterMetadata.Aliases; $ref.Value.IsDynamic = $ParameterMetadata.IsDynamic; $ref.Value.Attributes = $ParameterMetadata.Attributes;
    $ref.Value.PsObject.properties.add([psscriptproperty]::new('Name', [scriptblock]::Create("return '$Name'"), { throw "'Name' is a ReadOnly property." }));
    $ref.Value.PsObject.properties.add([psscriptproperty]::new('IsSwitch', [scriptblock]::Create("return [bool]$([int]$ParameterMetadata.SwitchParameter)"), { throw "'IsSwitch' is a ReadOnly property." }));
    $ref.Value.PsObject.properties.add([psscriptproperty]::new('ParameterType', [scriptblock]::Create("return [Type]'$PType'"), { throw "'ParameterType' is a ReadOnly property." }));
    $ref.Value.PsObject.properties.add([psscriptproperty]::new('DefaultValue', [scriptblock]::Create('return $(switch ($this.ParameterType) { ([bool]) { $false } ([string]) { [string]::Empty } ([array]) { @() } ([hashtable]) { @{} } Default { $null } }) -as $this.ParameterType'), { throw "'DefaultValue' is a ReadOnly property." }));
    $ref.Value.PsObject.properties.add([psscriptproperty]::new('RawDefaultValue', [scriptblock]::Create('return $this.DefaultValue.ToString()'), { throw "'RawDefaultValue' is a ReadOnly property." }));
    $ref.Value.PsObject.properties.add([psscriptproperty]::new('HasDefaultValue', [scriptblock]::Create('return $($null -ne $this.DefaultValue)'), { throw "'HasDefaultValue' is a ReadOnly property." })); return $ref.Value
  }
  [string] ToString() {
    return '{0}${1}' -f $($this.IsSwitch ? '[switch]' : '[Parameter()]'), $this.Name
  }
}

class ParamDictionary {
  [bool] $IsReadOnly = $false
  hidden [Dictionary[string, ParamBase]] $_int_d

  ParamDictionary() {
    [ParamDictionary]::From($null, [ref]$this)
  }
  ParamDictionary([Object[]]$params) {
    [ParamDictionary]::From([ParamBase[]]$params, [ref]$this)
  }
  ParamDictionary([ParamBase[]]$params) {
    [ParamDictionary]::From($params, [ref]$this)
  }
  static [ParamDictionary] Create() {
    return [ParamDictionary]::new()
  }
  static [ParamDictionary] Create([Object[]]$params) {
    return [ParamDictionary]::Create([ParamBase[]]$params)
  }
  static [ParamDictionary] Create([ParamBase[]]$params) {
    return [ParamDictionary]::new($params)
  }
  static hidden [ParamDictionary] From([ParamBase[]]$params, [ref]$ref) {
    $ref.Value._int_d = [Dictionary[string, ParamBase]]::new()
    $ref.Value.PsObject.Properties.Add([psscriptproperty]::new('Count', { return $this._int_d.Count }, { throw "'Count' is a ReadOnly property." }))
    $ref.Value.PsObject.Properties.Add([psscriptproperty]::new('Keys', { return [System.Collections.Generic.ICollection[string]]$this._int_d.Keys }), { throw "'Keys' is a ReadOnly property." })
    $ref.Value.PsObject.Properties.Add([psscriptproperty]::new('Values', { return [System.Collections.Generic.ICollection[ParamBase]]$this._int_d.Values }, { throw "'Values' is a ReadOnly property." }))
    $params.ForEach({ $this._int_d.Add($_.Name, $_) })
    return $ref.Value
  }
  [void] Add([string]$key, [ParamBase]$value) {
    $this._int_d.Add($key, $value)
  }
  [void] Add([string]$key, [Object[]]$param) {
    $this.Add($key, [ParamBase]::new($param))
  }
  [void] Add([KeyValuePair[string, ParamBase]] $item) {
    $this._int_d.Add($item.Key, $item.Value)
  }
  [bool] Contains([KeyValuePair[string, ParamBase]] $item) {
    return $this._int_d.ContainsKey($item.Key) -and [ParamBase]::Equals($this._int_d[$item.Key], $item.Value)
  }
  [bool] ContainsKey([string] $key) {
    return $this._int_d.ContainsKey($key)
  }
  [bool] Remove([string] $key) {
    return $this._int_d.Remove($key)
  }
  [bool] TryGetValue([string]$key, [ref]$value) {
    return $this._int_d.TryGetValue($key, [ref]$value)
  }
  [void] CopyTo([KeyValuePair[string, ParamBase][]] $array, [int] $arrayIndex) {
    $index = $arrayIndex
    foreach ($item in $this._int_d) {
      $array[$index] = $item
      $index++
    }
  }
  [bool] Remove([KeyValuePair[string, ParamBase]] $item) {
    if ($this._int_d.ContainsKey($item.Key) -and [ParamBase]::Equals($this._int_d[$item.Key], $item.Value)) {
      return $this._int_d.Remove($item.Key)
    }
    return $false
  }
  [IEnumerator[KeyValuePair[string, ParamBase]]] GetEnumerator() {
    return $this._int_d.GetEnumerator()
  }
  [System.Collections.IEnumerator] IEnumerable_GetEnumerator() {
    return $this._int_d.GetEnumerator()
  }
  [ParamBase] get_Item([string]$key) {
    return $this._int_d[$key]
  }
  [void] set_Item([string]$key, [ParamBase]$value) {
    $this._int_d[$key] = $value
  }
  [void] set_Item([string]$key, [Object[]]$param) {
    $this.set_Item($key, [ParamBase]::new($param))
  }
  [void] Clear() {
    $this._int_d.Clear()
  }
}

<#
.SYNOPSIS
  ArgParser takes an array of command-line arguments and parses them according to the parameters specified using AddParameter. returns a dictionary containing the parsed values.
.EXAMPLE
  $argvr = '--format=gnu -f --quoting-style=escape --rmt-command=/usr/lib/tar/rmt -delete-key=2 --filter name1 name2'.Split(' ')
  $list = [ArgParser]::Parse($argvr, [ParamDictionary]@(
      ('f', [switch], $false),
      ('format', [string], $false),
      ('rmt-command', [String], ''),
      ('quoting-style', [String], ''),
      ('delete-key', [int[]], $null),
      ('filter', [String[]], $null)
    )
  )
#>
class ArgParser {
  ArgParser() {}

  static [Dictionary[String, ParamBase]] Parse([string[]]$argvr, [ParamDictionary]$BaseDictionary) {
    [ValidateNotNullOrEmpty()][ParamDictionary]$BaseDictionary = $BaseDictionary
    [ValidateNotNullOrEmpty()][string[]]$argvr = $argvr
    $paramDict = [ParamDictionary]::new()
    for ($i = 0; $i -lt $argvr.Count; $i++) {
      $arg = $argvr[$i]; ($name, $IsParam) = switch ($true) {
        $arg.StartsWith('--') { $arg.Substring(2), $true; break }
        $arg.StartsWith('-') { $arg.Substring(1), $true; break }
        Default { $arg, $false }
      }
      if ($IsParam) {
        $has_eq = $name.Contains('=')
        if ($has_eq) { $name = $name.Substring(0, $name.IndexOf('=')) }
        $bParam_Index = $BaseDictionary.Keys.Where({ $_ -match $name })
        $IsKnownParam = $null -ne $bParam_Index; $Param = $IsKnownParam ? $BaseDictionary.get_Item($name) : $null
        $IsKnownParam = $null -ne $Param
        if ($IsKnownParam) {
          if (!$has_eq) {
            $i++; $argVal = $argvr[$i]
            if ($Param.ParameterType.IsArray) {
              $arr = [System.Collections.Generic.List[Object]]::new()
              while ($i -lt $argvr.Count -and !$argvr[$i].StartsWith('-')) {
                $arr.Add($argVal); $i++; $argVal = $argvr[$i]
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
    return $paramDict._int_d
  }
  static [System.Collections.Generic.Dictionary[String, ParamBase]] Parse([string[]]$argvr, [System.Collections.Generic.Dictionary[System.Management.Automation.ParameterMetadata, object]]$ParamBase) {
    $BaseDictionary = [System.Collections.Generic.Dictionary[String, ParamBase]]::New(); $ParamBase.Keys | ForEach-Object { $BaseDictionary.Add($_.Name, [ParamBase]::new($_.Name, $_.ParameterType, $ParamBase[$_])) }
    return [ArgParser]::Parse($argvr, $BaseDictionary)
  }
  # A method to convert parameter names from their command-line format (using dashes) to their property name format (using PascalCase).
  static hidden [string] MungeName([string]$name) {
    return [string]::Join('', ($name.Split('-') | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }))
  }
}

# $stream = @('str', 'eam', 'mm');
# $filter = @('ffffil', 'llll', 'tttr', 'rrr');
# $excludestr = @('sss', 'ddd', 'ggg', 'hhh');
# $dkey = [consolekey]::S;
# $argvr = '--format=gnu -f- -b20 --quoting-style=escape --rmt-command=/usr/lib/tar/rmt -DeleteKey [consolekey]$dkey -Exclude [string[]]$excludestr -Filter [string[]]$filter -Force -Include [string[]]$IncludeStr -Recurse -Stream [string[]]$stream -Confirm -WhatIf'.Split(' ')

class argvtest {

  hidden [System.Collections.Generic.Dictionary[String, ParamBase]] ParseArgs([string[]]$argv) {
    $ParsedArgs = $null;
    $BaseDictionary = [System.Collections.Generic.Dictionary[String, ParamBase]]::new()
    # Set default types and values for parameter Ex: packages is expected to be string[] and its default value is $null.
    @(
      ('Force', [System.Management.Automation.SwitchParameter], $null),
      ('WhatIf', [System.Management.Automation.SwitchParameter], $null),
      ('Exclude', [System.String[]], $null),
      ('Include', [System.String[]], $null),
      ('LiteralPath', [System.String[]], $null)
    )
    try {
      $parsedArgs = [ArgParser]::Parse($argv, $BaseDictionary)
    } catch {
      throw [System.Management.Automation.ParseException]::new('Failed to parse arguments', $_)
    }
    $ComndName = [string](Get-Variable MyInvocation).value.MyCommand.Name
    if ($ComndName -in $parsedArgs['packages']) { $parsedArgs['packages'].Remove($ComndName) }
    #dotfilePaths: An array or list of all dotfile paths managed by the app.
    $this.PsObject.properties.add([psscriptproperty]::new('dotfilePaths', [scriptblock]::Create('$dirs = [System.Collections.Generic.IEnumerable[string]]::new(); foreach ($packageName in $this.args["packages"]) { [void]$dirs.add([IO.Path]::Combine($this.args["source"], $packageName)) }; return $dirs')))
    return $ParsedArgs
  }
}
#endregion Classes
# Types that will be available to users when they import the module.
$typestoExport = @(
  [ArgParser], [ParamBase], [ParamDictionary]
)
$TypeAcceleratorsClass = [PsObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
foreach ($Type in $typestoExport) {
  if ($Type.FullName -in $TypeAcceleratorsClass::Get.Keys) {
    $Message = @(
      "InvalidOperation : TypeAcceleratorAlreadyExists"
      "Unable to register type accelerator '$($Type.FullName)'"
    ) -join ' - '
    $Message | Write-Warning
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
