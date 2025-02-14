
# [argparser](https://www.powershellgallery.com/packages/ArgParser) -	βeta v0.1.0

A module to parse and convert command-line arguments (strings) into typed parameters.

**`Why?`**

⤷ Sometimes you want your script to behave more like an og command-line app but with more type-safety powers.

⤷ Parameters are cool.

## Usage

```PowerShell
Install-Module ArgParser

# then
Import-Module ArgParser
# do stuff like:

$line = '--format=gnu -f --quoting-style=escape --rmt-command=/usr/lib/tar/rmt -delete-key=2 --filter name1 name2'
$list = $line.Split(' ')
$_out = $list | ConvertTo-Params @(
  ('f', [switch], $false),
  ('format', [string], $false),
  ('rmt-command', [String], ''),
  ('quoting-style', [String], ''),
  ('delete-key', [int[]], $null),
  ('filter', [String[]], $null)
)
$_out
```

## License

This project is licensed under the [WTFPL License](LICENSE).