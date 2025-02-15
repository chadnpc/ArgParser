using namespace System.Reflection
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Collections.ObjectModel
#!/usr/bin/env pwsh

#region    Classes
class Parsedarg {
  [int] $Index
  [string] $Name
  [bool] $IsKnown
  [bool] $IsArray
  [bool] $IsSwitch
  [bool] $HasEqualSign
  [Object] $DefaultValue
  [Type] $ParameterType
  Parsedarg() {}
  Parsedarg([Hashtable]$Object) {
    $Object.Keys.ForEach({ $this.$_ = $Object[$_] })
  }
}

class ParamBase : ParameterInfo {
  [bool]$IsDynamic
  [System.Object]$Value
  [Collection[string]]$Aliases
  [Collection[Attribute]]$Attributes
  [IEnumerable[CustomAttributeData]]$CustomAttributes

  ParamBase([string]$Name) {
    [void][ParamBase]::From($Name, [System.Management.Automation.SwitchParameter], $null, [ref]$this)
  }
  ParamBase([Object[]]$argumentlist) {
    [void][ParamBase]::From([string]$argumentlist[0], [type]$argumentlist[1], [System.Object]$argumentlist[2], [ref]$this)
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
<#
.EXAMPLE
  [ParamSchema]@(
    ('font', [string], "NotoSansMono-Regular"),
    ('force', [switch], $false),
    ('verbose', [switch], $false)
  )
#>
class ParamSchema {
  [bool] $IsReadOnly = $false
  hidden [Dictionary[string, ParamBase]] $_int_d

  ParamSchema() {
    [ParamSchema]::From($null, [ref]$this)
  }
  ParamSchema([Object[]]$params) {
    [ParamSchema]::From([ParamBase[]]$params, [ref]$this)
  }
  ParamSchema([ParamBase[]]$params) {
    [ParamSchema]::From($params, [ref]$this)
  }
  static [ParamSchema] Create() {
    return [ParamSchema]::new()
  }
  static [ParamSchema] Create([Object[]]$params) {
    return [ParamSchema]::Create([ParamBase[]]$params)
  }
  static [ParamSchema] Create([ParamBase[]]$params) {
    return [ParamSchema]::new($params)
  }
  static hidden [ParamSchema] From([ParamBase[]]$params, [ref]$ref) {
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
  [Dictionary[string, ParamBase]] ToDictionary() {
    return $this._int_d
  }
  [void] CopyTo([KeyValuePair[string, ParamBase][]] $argumentlist, [int] $argumentlistIndex) {
    $index = $argumentlistIndex
    foreach ($item in $this._int_d) {
      $argumentlist[$index] = $item
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


class ArgParser {
  hidden [Parsedarg[]]$INFERRED
  hidden [version]$VERSION = [version]'0.1.1'
  hidden [ValidateNotNullOrEmpty()][ParamSchema]$schema
  hidden [KeyValuePair[String, Parsedarg][]]$_map = @()
  hidden [ValidateNotNullOrEmpty()][string[]]$_array
  hidden [int]$ci = 0

  ArgParser([Object[]]$schema) {
    $this.schema = [ParamSchema]::Create($schema)
  }
  ArgParser([ParamSchema]$schema) { $this.schema = $schema }

  [Dictionary[String, ParamBase]] Parse([string[]]$argumentlist) {
    $result = [Dictionary[String, ParamBase]]::New(); [void]$this.read_list($argumentlist);
    if ($this.INFERRED.Count -gt 0) {
      foreach ($item in $this.INFERRED) {
        $result.Add($item.Name, [ParamBase]::New($item.Name, $item.ParameterType, $this.get_value($item.Name)))
      }
    }
    return $result
  }
  [Dictionary[String, ParamBase]] Parse([string[]]$argumentlist, [Dictionary[ParameterMetadata, object]]$metadata) {
    $_schema = [Dictionary[String, ParamBase]]::New(); $metadata.Keys.ForEach({ $_schema.Add($_.Name, [ParamBase]::new($_.Name, $_.ParameterType, $metadata[$_])) })
    return $this.Parse($argumentlist, $_schema)
  }
  [Object] get_value([string]$Name) {
    $value = $null; $done = $false # means we got a value or we just have to stop.
    $knval = $this.INFERRED.Where({ $_.Name -eq $Name })[0]; $this.ci = $knval.Index
    do {
      switch ($true) {
        $($this._map[$this.ci].Value.HasEqualSign -and !$this._map[$this.ci].Value.IsArray) {
          $value = $this._array[$this.ci].Substring($this._array[$this.ci].IndexOf('=') + 1);
          $done = $null -ne $value; if (!$done) { $this.ci++ }
          break
        }
        Default {
          $_values = @();
          While (!$done -and $this.ci -lt $this._array.Count) {
            $_v = $this._array[$this.ci]
            if ($this._map[$this.ci].Value.HasEqualSign) {
              $_v = $_v.Substring($_v.IndexOf('=') + 1)
            }
            if (!$_v.StartsWith('-')) { $_values += $_v }
            $next = $this._array[$this.ci + 1]
            $cont = $next ? !$next.StartsWith('-') : $false
            $cont ? ($this.ci++) : ($done = $true)
          }
          $value = $_values -as $this._map[$knval.Index].Value.ParameterType
        }
      }
      if ($done) { $this.ci = 0 }
    } until ($done -or $this.ci -ge $this._array.Count)
    $result = ($null -eq $value) ? $knval.DefaultValue : $value
    return $result
  }
  [void] read_list([string[]]$argumentlist) {
    $this._array = $argumentlist
    for ($i = 0; $i -lt $this._array.Count; $i++) {
      $name = $this._array[$i]
      $name = $name.TrimStart('-'); $HasEqualSign = $name.Contains('=')
      $name = $HasEqualSign ? $name.Substring(0, $name.IndexOf('=')) : $name
      $scpv = $this.schema.get_Item($name)
      $Is_known_key = $this.schema.ContainsKey($name)
      $Is_Array = $Is_known_key ? $scpv.ParameterType.IsArray : $false
      $this._map += [KeyValuePair[String, Parsedarg]]::new($i, [Parsedarg]@{
          Name          = $name
          Index         = $i
          IsKnown       = $Is_known_key
          IsArray       = $Is_Array
          IsSwitch      = $Is_known_key ? $scpv.IsSwitch : $false
          DefaultValue  = $Is_known_key ? $scpv.DefaultValue : $null
          HasEqualSign  = $HasEqualSign
          ParameterType = $Is_known_key ? $scpv.ParameterType : $($Is_Array ? [string[]] : [string])
        }
      )
    }
    $this.INFERRED = $this._map.Value.Where({ $_.IsKnown }) | Select-Object * -Exclude IsKnown | Sort-Object -Unique Index
  }
  [string] MungeName([string]$name) {
    # converts parameter names from their command-line format (using dashes) to their property name format.
    return [string]::Join('', ($name.Split('-') | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }))
  }
  [string] ToString() {
    return $this.INFERRED ? $this.INFERRED.ToString() : 'ArgParser'
  }
}

#endregion Classes

# Types that will be available to users when they import the module.
$typestoExport = @(
  [ArgParser], [ParamBase], [Parsedarg], [ParamSchema]
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
