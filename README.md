
## [argparser](https://www.powershellgallery.com/packages/ArgParser)

A module to parse and convert command-line arguments (strings) into typed parameters.

**`Why?`**

⤷ Sometimes you want your script to behave more like an og command-line app but with more type-safety powers.

⤷ Parameters are cool.

## Usage

```PowerShell
Install-Module ArgParser

# First import the module or add a '#Requires -Modules ArgParser' to ur script:
Import-Module ArgParser

# then do stuff like:
$line = '--verbose -t 30 --retry=5 --output=log.txt --include=*.txt *.csv'
$list = $line -split ' '

# Then run:
$params = ConvertTo-Params $list @(
  ('verbose', [switch], $false),
  ('t', [int], 0),
  ('retry', [int], 3),
  ('output', [string], 'output.log'),
  ('include', [string[]], @())
)

echo $params
# Results in this dictionary:

Key     Value
---     -----
verbose [switch]$verbose
timeout [Parameter()]$timeout
retry   [Parameter()]$retry
output  [Parameter()]$output
include [Parameter()]$include

# Explore the results more:
$params['include']

Name             : include
IsSwitch         : False
ParameterType    : System.String[]
DefaultValue     :
RawDefaultValue  :
HasDefaultValue  : False
IsDynamic        : False
Value            : {*.txt, *.csv}
.....
```

## License

This project is licensed under the [WTFPL License](LICENSE).