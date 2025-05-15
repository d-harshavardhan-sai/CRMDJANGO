<#
.Synopsis
Activate a Python virtual environment for the current PowerShell session.

.Description
Pushes the python executable for a virtual environment to the front of the
$Env:PATH environment variable and sets the prompt to signify that you are
in a Python virtual environment. Makes use of the command line switches as
well as the `pyvenv.cfg` file values present in the virtual environment.

.Parameter VenvDir
Path to the directory that contains the virtual environment to activate. The
default value for this is the parent of the directory that the Activate.ps1
script is located within.

.Parameter Prompt
The prompt prefix to display when this virtual environment is activated. By
default, this prompt is the name of the virtual environment folder (VenvDir)
surrounded by parentheses and followed by a single space (ie. '(.venv) ').

.Example
Activate.ps1
Activates the Python virtual environment that contains the Activate.ps1 script.

.Example
Activate.ps1 -Verbose
Activates the Python virtual environment that contains the Activate.ps1 script,
and shows extra information about the activation as it executes.

.Example
Activate.ps1 -VenvDir C:\Users\MyUser\Common\.venv
Activates the Python virtual environment located in the specified location.

.Example
Activate.ps1 -Prompt "MyPython"
Activates the Python virtual environment that contains the Activate.ps1 script,
and prefixes the current prompt with the specified string (surrounded in
parentheses) while the virtual environment is active.

.Notes
On Windows, it may be required to enable this Activate.ps1 script by setting the
execution policy for the user. You can do this by issuing the following PowerShell
command:

PS C:\> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

For more information on Execution Policies: 
https://go.microsoft.com/fwlink/?LinkID=135170

#>
Param(
    [Parameter(Mandatory = $false)]
    [String]
    $VenvDir,
    [Parameter(Mandatory = $false)]
    [String]
    $Prompt
)

<# Function declarations --------------------------------------------------- #>

<#
.Synopsis
Remove all shell session elements added by the Activate script, including the
addition of the virtual environment's Python executable from the beginning of
the PATH variable.

.Parameter NonDestructive
If present, do not remove this function from the global namespace for the
session.

#>
function global:deactivate ([switch]$NonDestructive) {
    # Revert to original values

    # The prior prompt:
    if (Test-Path -Path Function:_OLD_VIRTUAL_PROMPT) {
        Copy-Item -Path Function:_OLD_VIRTUAL_PROMPT -Destination Function:prompt
        Remove-Item -Path Function:_OLD_VIRTUAL_PROMPT
    }

    # The prior PYTHONHOME:
    if (Test-Path -Path Env:_OLD_VIRTUAL_PYTHONHOME) {
        Copy-Item -Path Env:_OLD_VIRTUAL_PYTHONHOME -Destination Env:PYTHONHOME
        Remove-Item -Path Env:_OLD_VIRTUAL_PYTHONHOME
    }

    # The prior PATH:
    if (Test-Path -Path Env:_OLD_VIRTUAL_PATH) {
        Copy-Item -Path Env:_OLD_VIRTUAL_PATH -Destination Env:PATH
        Remove-Item -Path Env:_OLD_VIRTUAL_PATH
    }

    # Just remove the VIRTUAL_ENV altogether:
    if (Test-Path -Path Env:VIRTUAL_ENV) {
        Remove-Item -Path env:VIRTUAL_ENV
    }

    # Just remove VIRTUAL_ENV_PROMPT altogether.
    if (Test-Path -Path Env:VIRTUAL_ENV_PROMPT) {
        Remove-Item -Path env:VIRTUAL_ENV_PROMPT
    }

    # Just remove the _PYTHON_VENV_PROMPT_PREFIX altogether:
    if (Get-Variable -Name "_PYTHON_VENV_PROMPT_PREFIX" -ErrorAction SilentlyContinue) {
        Remove-Variable -Name _PYTHON_VENV_PROMPT_PREFIX -Scope Global -Force
    }

    # Leave deactivate function in the global namespace if requested:
    if (-not $NonDestructive) {
        Remove-Item -Path function:deactivate
    }
}

<#
.Description
Get-PyVenvConfig parses the values from the pyvenv.cfg file located in the
given folder, and returns them in a map.

For each line in the pyvenv.cfg file, if that line can be parsed into exactly
two strings separated by `=` (with any amount of whitespace surrounding the =)
then it is considered a `key = value` line. The left hand string is the key,
the right hand is the value.

If the value starts with a `'` or a `"` then the first and last character is
stripped from the value before being captured.

.Parameter ConfigDir
Path to the directory that contains the `pyvenv.cfg` file.
#>
function Get-PyVenvConfig(
    [String]
    $ConfigDir
) {
    Write-Verbose "Given ConfigDir=$ConfigDir, obtain values in pyvenv.cfg"

    # Ensure the file exists, and issue a warning if it doesn't (but still allow the function to continue).
    $pyvenvConfigPath = Join-Path -Resolve -Path $ConfigDir -ChildPath 'pyvenv.cfg' -ErrorAction Continue

    # An empty map will be returned if no config file is found.
    $pyvenvConfig = @{ }

    if ($pyvenvConfigPath) {

        Write-Verbose "File exists, parse `key = value` lines"
        $pyvenvConfigContent = Get-Content -Path $pyvenvConfigPath

        $pyvenvConfigContent | ForEach-Object {
            $keyval = $PSItem -split "\s*=\s*", 2
            if ($keyval[0] -and $keyval[1]) {
                $val = $keyval[1]

                # Remove extraneous quotations around a string value.
                if ("'""".Contains($val.Substring(0, 1))) {
                    $val = $val.Substring(1, $val.Length - 2)
                }

                $pyvenvConfig[$keyval[0]] = $val
                Write-Verbose "Adding Key: '$($keyval[0])'='$val'"
            }
        }
    }
    return $pyvenvConfig
}


<# Begin Activate script --------------------------------------------------- #>

# Determine the containing directory of this script
$VenvExecPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$VenvExecDir = Get-Item -Path $VenvExecPath

Write-Verbose "Activation script is located in path: '$VenvExecPath'"
Write-Verbose "VenvExecDir Fullname: '$($VenvExecDir.FullName)"
Write-Verbose "VenvExecDir Name: '$($VenvExecDir.Name)"

# Set values required in priority: CmdLine, ConfigFile, Default
# First, get the location of the virtual environment, it might not be
# VenvExecDir if specified on the command line.
if ($VenvDir) {
    Write-Verbose "VenvDir given as parameter, using '$VenvDir' to determine values"
}
else {
    Write-Verbose "VenvDir not given as a parameter, using parent directory name as VenvDir."
    $VenvDir = $VenvExecDir.Parent.FullName.TrimEnd("\\/")
    Write-Verbose "VenvDir=$VenvDir"
}

# Next, read the `pyvenv.cfg` file to determine any required value such
# as `prompt`.
$pyvenvCfg = Get-PyVenvConfig -ConfigDir $VenvDir

# Next, set the prompt from the command line, or the config file, or
# just use the name of the virtual environment folder.
if ($Prompt) {
    Write-Verbose "Prompt specified as argument, using '$Prompt'"
}
else {
    Write-Verbose "Prompt not specified as argument to script, checking pyvenv.cfg value"
    if ($pyvenvCfg -and $pyvenvCfg['prompt']) {
        Write-Verbose "  Setting based on value in pyvenv.cfg='$($pyvenvCfg['prompt'])'"
        $Prompt = $pyvenvCfg['prompt'];
    }
    else {
        Write-Verbose "  Setting prompt based on parent's directory's name. (Is the directory name passed to venv module when creating the virtual environment)"
        Write-Verbose "  Got leaf-name of $VenvDir='$(Split-Path -Path $venvDir -Leaf)'"
        $Prompt = Split-Path -Path $venvDir -Leaf
    }
}

Write-Verbose "Prompt = '$Prompt'"
Write-Verbose "VenvDir='$VenvDir'"

# Deactivate any currently active virtual environment, but leave the
# deactivate function in place.
deactivate -nondestructive

# Now set the environment variable VIRTUAL_ENV, used by many tools to determine
# that there is an activated venv.
$env:VIRTUAL_ENV = $VenvDir

$env:VIRTUAL_ENV_PROMPT = $Prompt

if (-not $Env:VIRTUAL_ENV_DISABLE_PROMPT) {

    Write-Verbose "Setting prompt to '$Prompt'"

    # Set the prompt to include the env name
    # Make sure _OLD_VIRTUAL_PROMPT is global
    function global:_OLD_VIRTUAL_PROMPT { "" }
    Copy-Item -Path function:prompt -Destination function:_OLD_VIRTUAL_PROMPT
    New-Variable -Name _PYTHON_VENV_PROMPT_PREFIX -Description "Python virtual environment prompt prefix" -Scope Global -Option ReadOnly -Visibility Public -Value $Prompt

    function global:prompt {
        Write-Host -NoNewline -ForegroundColor Green "($_PYTHON_VENV_PROMPT_PREFIX) "
        _OLD_VIRTUAL_PROMPT
    }
}

# Clear PYTHONHOME
if (Test-Path -Path Env:PYTHONHOME) {
    Copy-Item -Path Env:PYTHONHOME -Destination Env:_OLD_VIRTUAL_PYTHONHOME
    Remove-Item -Path Env:PYTHONHOME
}

# Add the venv to the PATH
Copy-Item -Path Env:PATH -Destination Env:_OLD_VIRTUAL_PATH
$Env:PATH = "$VenvExecDir$([System.IO.Path]::PathSeparator)$Env:PATH"

# SIG # Begin signature block
# MII0BwYJKoZIhvcNAQcCoIIz+DCCM/QCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBALKwKRFIhr2RY
# IW/WJLd9pc8a9sj/IoThKU92fTfKsKCCG9IwggXMMIIDtKADAgECAhBUmNLR1FsZ
# lUgTecgRwIeZMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29mdCBJZGVu
# dGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAy
# MDAeFw0yMDA0MTYxODM2MTZaFw00NTA0MTYxODQ0NDBaMHcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jv
# c29mdCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRo
# b3JpdHkgMjAyMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALORKgeD
# Bmf9np3gx8C3pOZCBH8Ppttf+9Va10Wg+3cL8IDzpm1aTXlT2KCGhFdFIMeiVPvH
# or+Kx24186IVxC9O40qFlkkN/76Z2BT2vCcH7kKbK/ULkgbk/WkTZaiRcvKYhOuD
# PQ7k13ESSCHLDe32R0m3m/nJxxe2hE//uKya13NnSYXjhr03QNAlhtTetcJtYmrV
# qXi8LW9J+eVsFBT9FMfTZRY33stuvF4pjf1imxUs1gXmuYkyM6Nix9fWUmcIxC70
# ViueC4fM7Ke0pqrrBc0ZV6U6CwQnHJFnni1iLS8evtrAIMsEGcoz+4m+mOJyoHI1
# vnnhnINv5G0Xb5DzPQCGdTiO0OBJmrvb0/gwytVXiGhNctO/bX9x2P29Da6SZEi3
# W295JrXNm5UhhNHvDzI9e1eM80UHTHzgXhgONXaLbZ7LNnSrBfjgc10yVpRnlyUK
# xjU9lJfnwUSLgP3B+PR0GeUw9gb7IVc+BhyLaxWGJ0l7gpPKWeh1R+g/OPTHU3mg
# trTiXFHvvV84wRPmeAyVWi7FQFkozA8kwOy6CXcjmTimthzax7ogttc32H83rwjj
# O3HbbnMbfZlysOSGM1l0tRYAe1BtxoYT2v3EOYI9JACaYNq6lMAFUSw0rFCZE4e7
# swWAsk0wAly4JoNdtGNz764jlU9gKL431VulAgMBAAGjVDBSMA4GA1UdDwEB/wQE
# AwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTIftJqhSobyhmYBAcnz1AQ
# T2ioojAQBgkrBgEEAYI3FQEEAwIBADANBgkqhkiG9w0BAQwFAAOCAgEAr2rd5hnn
# LZRDGU7L6VCVZKUDkQKL4jaAOxWiUsIWGbZqWl10QzD0m/9gdAmxIR6QFm3FJI9c
# Zohj9E/MffISTEAQiwGf2qnIrvKVG8+dBetJPnSgaFvlVixlHIJ+U9pW2UYXeZJF
# xBA2CFIpF8svpvJ+1Gkkih6PsHMNzBxKq7Kq7aeRYwFkIqgyuH4yKLNncy2RtNwx
# AQv3Rwqm8ddK7VZgxCwIo3tAsLx0J1KH1r6I3TeKiW5niB31yV2g/rarOoDXGpc8
# FzYiQR6sTdWD5jw4vU8w6VSp07YEwzJ2YbuwGMUrGLPAgNW3lbBeUU0i/OxYqujY
# lLSlLu2S3ucYfCFX3VVj979tzR/SpncocMfiWzpbCNJbTsgAlrPhgzavhgplXHT2
# 6ux6anSg8Evu75SjrFDyh+3XOjCDyft9V77l4/hByuVkrrOj7FjshZrM77nq81YY
# uVxzmq/FdxeDWds3GhhyVKVB0rYjdaNDmuV3fJZ5t0GNv+zcgKCf0Xd1WF81E+Al
# GmcLfc4l+gcK5GEh2NQc5QfGNpn0ltDGFf5Ozdeui53bFv0ExpK91IjmqaOqu/dk
# ODtfzAzQNb50GQOmxapMomE2gj4d8yu8l13bS3g7LfU772Aj6PXsCyM2la+YZr9T
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggb+MIIE5qADAgECAhMzAAM/y2Wy
# WWnFfpZcAAAAAz/LMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDEwHhcNMjUwNDA4MDEwNzI0WhcNMjUwNDEx
# MDEwNzI0WjB8MQswCQYDVQQGEwJVUzEPMA0GA1UECBMGT3JlZ29uMRIwEAYDVQQH
# EwlCZWF2ZXJ0b24xIzAhBgNVBAoTGlB5dGhvbiBTb2Z0d2FyZSBGb3VuZGF0aW9u
# MSMwIQYDVQQDExpQeXRob24gU29mdHdhcmUgRm91bmRhdGlvbjCCAaIwDQYJKoZI
# hvcNAQEBBQADggGPADCCAYoCggGBAI0elXEcbTdGLOszMU2fzimHGM9Y4EjwFgC2
# iGPdieHc0dK1DyEIdtnvjKxnG/KICC3J2MrhePGzMEkie3yQjx05B5leG0q8YoGU
# m9z9K67V6k3DSXX0vQe9FbaNVuyXed31MEf/qek7Zo4ELxu8n/LO3ibURBLRHNoW
# Dz9zr4DcU+hha0bdIL6SnKMLwHqRj59gtFFEPqXcOVO7kobkzQS3O1T5KNL/zGuW
# UGQln7fS4YI9bj24bfrSeG/QzLgChVYScxnUgjAANfT1+SnSxrT4/esMtfbcvfID
# BIvOWk+FPPj9IQWsAMEG/LLG4cF/pQ/TozUXKx362GJBbe6paTM/RCUTcffd83h2
# bXo9vXO/roZYk6H0ecd2h2FFzLUQn/0i4RQQSOp6zt1eDf28h6F8ev+YYKcChph8
# iRt32bJPcLQVbUzhehzT4C0pz6oAqPz8s0BGvlj1G6r4CY1Cs2YiMU09/Fl64pWf
# IsA/ReaYj6yNsgQZNUcvzobK2mTxMwIDAQABo4ICGTCCAhUwDAYDVR0TAQH/BAIw
# ADAOBgNVHQ8BAf8EBAMCB4AwPAYDVR0lBDUwMwYKKwYBBAGCN2EBAAYIKwYBBQUH
# AwMGGysGAQQBgjdhgqKNuwqmkohkgZH0oEWCk/3hbzAdBgNVHQ4EFgQU4Y4Xr/Xn
# zEXblXrNC0ZLdaPEJYUwHwYDVR0jBBgwFoAU6IPEM9fcnwycdpoKptTfh6ZeWO4w
# ZwYDVR0fBGAwXjBcoFqgWIZWaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0El
# MjAwMS5jcmwwgaUGCCsGAQUFBwEBBIGYMIGVMGQGCCsGAQUFBzAChlhodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDEuY3J0MC0GCCsGAQUFBzABhiFo
# dHRwOi8vb25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwZgYDVR0gBF8wXTBRBgwr
# BgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMAgGBmeBDAEEATANBgkqhkiG
# 9w0BAQwFAAOCAgEAKTeVGPXsDKqQLe1OuKx6K6q711FPxNQyLOOqeenH8zybHwNo
# k05cMk39HQ7u+R9BQIL0bWexb7wa3XeKaX06p7aY/OQs+ycvUi/fC6RGlaLWmQ9D
# YhZn2TBz5znimvSf3P+aidCuXeDU5c8GpBFog6fjEa/k+n7TILi0spuYZ4yC9R48
# R63/VvpLi2SqxfJbx5n92bY6driNzAntjoravF25BSejXVrdzefbnqbQnZPB39g8
# XHygGPb0912fIuNKPLQa/uCnmYdXJnPb0ZgMxxA8fyxvL2Q30Qf5xpFDssPDElvD
# DoAbvR24CWvuHbu+CMMr2SJUpX4RRvDioO7JeB6wZb+64MXyPUSSf6QwkKNsHPIa
# e9tSfREh86sYn5bOA0Wd+Igk0RpA5jDRTu3GgPOPWbm1PU+VoeqThtHt6R3l17pr
# aQ5wIuuLXgxi1K4ZWgtvXw8BtIXfZz24qCtoo0+3kEGUpEHBgkF1SClbRb8uAzx+
# 0ROGniLPJRU20Xfn7CgipeKLcNn33JPFwQHk1zpbGS0090mi0erOQCz0S47YdHmm
# RJcbkNIL9DeNAglTZ/TFxrYUM1NRS1Cp4e63MgBKcWh9VJNokInzzmS+bofZz+u1
# mm8YNtiJjdT8fmizXdUEk68EXQhOs0+HBNvc9nMRK6R28MZu/J+PaUcPL84wggda
# MIIFQqADAgECAhMzAAAABzeMW6HZW4zUAAAAAAAHMA0GCSqGSIb3DQEBDAUAMGMx
# CzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xNDAy
# BgNVBAMTK01pY3Jvc29mdCBJRCBWZXJpZmllZCBDb2RlIFNpZ25pbmcgUENBIDIw
# MjEwHhcNMjEwNDEzMTczMTU0WhcNMjYwNDEzMTczMTU0WjBaMQswCQYDVQQGEwJV
# UzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNy
# b3NvZnQgSUQgVmVyaWZpZWQgQ1MgQU9DIENBIDAxMIICIjANBgkqhkiG9w0BAQEF
# AAOCAg8AMIICCgKCAgEAt/fAAygHxbo+jxA04hNI8bz+EqbWvSu9dRgAawjCZau1
# Y54IQal5ArpJWi8cIj0WA+mpwix8iTRguq9JELZvTMo2Z1U6AtE1Tn3mvq3mywZ9
# SexVd+rPOTr+uda6GVgwLA80LhRf82AvrSwxmZpCH/laT08dn7+Gt0cXYVNKJORm
# 1hSrAjjDQiZ1Jiq/SqiDoHN6PGmT5hXKs22E79MeFWYB4y0UlNqW0Z2LPNua8k0r
# bERdiNS+nTP/xsESZUnrbmyXZaHvcyEKYK85WBz3Sr6Et8Vlbdid/pjBpcHI+Hyt
# oaUAGE6rSWqmh7/aEZeDDUkz9uMKOGasIgYnenUk5E0b2U//bQqDv3qdhj9UJYWA
# DNYC/3i3ixcW1VELaU+wTqXTxLAFelCi/lRHSjaWipDeE/TbBb0zTCiLnc9nmOjZ
# PKlutMNho91wxo4itcJoIk2bPot9t+AV+UwNaDRIbcEaQaBycl9pcYwWmf0bJ4IF
# n/CmYMVG1ekCBxByyRNkFkHmuMXLX6PMXcveE46jMr9syC3M8JHRddR4zVjd/FxB
# nS5HOro3pg6StuEPshrp7I/Kk1cTG8yOWl8aqf6OJeAVyG4lyJ9V+ZxClYmaU5yv
# tKYKk1FLBnEBfDWw+UAzQV0vcLp6AVx2Fc8n0vpoyudr3SwZmckJuz7R+S79BzMC
# AwEAAaOCAg4wggIKMA4GA1UdDwEB/wQEAwIBhjAQBgkrBgEEAYI3FQEEAwIBADAd
# BgNVHQ4EFgQU6IPEM9fcnwycdpoKptTfh6ZeWO4wVAYDVR0gBE0wSzBJBgRVHSAA
# MEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMv
# RG9jcy9SZXBvc2l0b3J5Lmh0bTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAS
# BgNVHRMBAf8ECDAGAQH/AgEAMB8GA1UdIwQYMBaAFNlBKbAPD2Ns72nX9c0pnqRI
# ajDmMHAGA1UdHwRpMGcwZaBjoGGGX2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2RlJTIwU2ln
# bmluZyUyMFBDQSUyMDIwMjEuY3JsMIGuBggrBgEFBQcBAQSBoTCBnjBtBggrBgEF
# BQcwAoZhaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNy
# b3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ29kZSUyMFNpZ25pbmclMjBQQ0ElMjAy
# MDIxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0LmNv
# bS9vY3NwMA0GCSqGSIb3DQEBDAUAA4ICAQB3/utLItkwLTp4Nfh99vrbpSsL8NwP
# Ij2+TBnZGL3C8etTGYs+HZUxNG+rNeZa+Rzu9oEcAZJDiGjEWytzMavD6Bih3nEW
# FsIW4aGh4gB4n/pRPeeVrK4i1LG7jJ3kPLRhNOHZiLUQtmrF4V6IxtUFjvBnijaZ
# 9oIxsSSQP8iHMjP92pjQrHBFWHGDbkmx+yO6Ian3QN3YmbdfewzSvnQmKbkiTibJ
# gcJ1L0TZ7BwmsDvm+0XRsPOfFgnzhLVqZdEyWww10bflOeBKqkb3SaCNQTz8nsha
# UZhrxVU5qNgYjaaDQQm+P2SEpBF7RolEC3lllfuL4AOGCtoNdPOWrx9vBZTXAVdT
# E2r0IDk8+5y1kLGTLKzmNFn6kVCc5BddM7xoDWQ4aUoCRXcsBeRhsclk7kVXP+zJ
# GPOXwjUJbnz2Kt9iF/8B6FDO4blGuGrogMpyXkuwCC2Z4XcfyMjPDhqZYAPGGTUI
# NMtFbau5RtGG1DOWE9edCahtuPMDgByfPixvhy3sn7zUHgIC/YsOTMxVuMQi/bga
# memo/VNKZrsZaS0nzmOxKpg9qDefj5fJ9gIHXcp2F0OHcVwe3KnEXa8kqzMDfrRl
# /wwKrNSFn3p7g0b44Ad1ONDmWt61MLQvF54LG62i6ffhTCeoFT9Z9pbUo2gxlyTF
# g7Bm0fgOlnRfGDCCB54wggWGoAMCAQICEzMAAAAHh6M0o3uljhwAAAAAAAcwDQYJ
# KoZIhvcNAQEMBQAwdzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjFIMEYGA1UEAxM/TWljcm9zb2Z0IElkZW50aXR5IFZlcmlmaWNh
# dGlvbiBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDIwMB4XDTIxMDQwMTIw
# MDUyMFoXDTM2MDQwMTIwMTUyMFowYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlm
# aWVkIENvZGUgU2lnbmluZyBQQ0EgMjAyMTCCAiIwDQYJKoZIhvcNAQEBBQADggIP
# ADCCAgoCggIBALLwwK8ZiCji3VR6TElsaQhVCbRS/3pK+MHrJSj3Zxd3KU3rlfL3
# qrZilYKJNqztA9OQacr1AwoNcHbKBLbsQAhBnIB34zxf52bDpIO3NJlfIaTE/xrw
# eLoQ71lzCHkD7A4As1Bs076Iu+mA6cQzsYYH/Cbl1icwQ6C65rU4V9NQhNUwgrx9
# rGQ//h890Q8JdjLLw0nV+ayQ2Fbkd242o9kH82RZsH3HEyqjAB5a8+Ae2nPIPc8s
# ZU6ZE7iRrRZywRmrKDp5+TcmJX9MRff241UaOBs4NmHOyke8oU1TYrkxh+YeHgfW
# o5tTgkoSMoayqoDpHOLJs+qG8Tvh8SnifW2Jj3+ii11TS8/FGngEaNAWrbyfNrC6
# 9oKpRQXY9bGH6jn9NEJv9weFxhTwyvx9OJLXmRGbAUXN1U9nf4lXezky6Uh/cgjk
# Vd6CGUAf0K+Jw+GE/5VpIVbcNr9rNE50Sbmy/4RTCEGvOq3GhjITbCa4crCzTTHg
# YYjHs1NbOc6brH+eKpWLtr+bGecy9CrwQyx7S/BfYJ+ozst7+yZtG2wR461uckFu
# 0t+gCwLdN0A6cFtSRtR8bvxVFyWwTtgMMFRuBa3vmUOTnfKLsLefRaQcVTgRnzeL
# zdpt32cdYKp+dhr2ogc+qM6K4CBI5/j4VFyC4QFeUP2YAidLtvpXRRo3AgMBAAGj
# ggI1MIICMTAOBgNVHQ8BAf8EBAMCAYYwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0O
# BBYEFNlBKbAPD2Ns72nX9c0pnqRIajDmMFQGA1UdIARNMEswSQYEVR0gADBBMD8G
# CCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3Mv
# UmVwb3NpdG9yeS5odG0wGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwDwYDVR0T
# AQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTIftJqhSobyhmYBAcnz1AQT2ioojCBhAYD
# VR0fBH0wezB5oHegdYZzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9j
# cmwvTWljcm9zb2Z0JTIwSWRlbnRpdHklMjBWZXJpZmljYXRpb24lMjBSb290JTIw
# Q2VydGlmaWNhdGUlMjBBdXRob3JpdHklMjAyMDIwLmNybDCBwwYIKwYBBQUHAQEE
# gbYwgbMwgYEGCCsGAQUFBzAChnVodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtp
# b3BzL2NlcnRzL01pY3Jvc29mdCUyMElkZW50aXR5JTIwVmVyaWZpY2F0aW9uJTIw
# Um9vdCUyMENlcnRpZmljYXRlJTIwQXV0aG9yaXR5JTIwMjAyMC5jcnQwLQYIKwYB
# BQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20vb2NzcDANBgkqhkiG
# 9w0BAQwFAAOCAgEAfyUqnv7Uq+rdZgrbVyNMul5skONbhls5fccPlmIbzi+OwVdP
# Q4H55v7VOInnmezQEeW4LqK0wja+fBznANbXLB0KrdMCbHQpbLvG6UA/Xv2pfpVI
# E1CRFfNF4XKO8XYEa3oW8oVH+KZHgIQRIwAbyFKQ9iyj4aOWeAzwk+f9E5StNp5T
# 8FG7/VEURIVWArbAzPt9ThVN3w1fAZkF7+YU9kbq1bCR2YD+MtunSQ1Rft6XG7b4
# e0ejRA7mB2IoX5hNh3UEauY0byxNRG+fT2MCEhQl9g2i2fs6VOG19CNep7SquKaB
# jhWmirYyANb0RJSLWjinMLXNOAga10n8i9jqeprzSMU5ODmrMCJE12xS/NWShg/t
# uLjAsKP6SzYZ+1Ry358ZTFcx0FS/mx2vSoU8s8HRvy+rnXqyUJ9HBqS0DErVLjQw
# K8VtsBdekBmdTbQVoCgPCqr+PDPB3xajYnzevs7eidBsM71PINK2BoE2UfMwxCCX
# 3mccFgx6UsQeRSdVVVNSyALQe6PT12418xon2iDGE81OGCreLzDcMAZnrUAx4XQL
# Uz6ZTl65yPUiOh3k7Yww94lDf+8oG2oZmDh5O1Qe38E+M3vhKwmzIeoB1dVLlz4i
# 3IpaDcR+iuGjH2TdaC1ZOmBXiCRKJLj4DT2uhJ04ji+tHD6n58vhavFIrmcxgheL
# MIIXhwIBATBxMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBBT0Mg
# Q0EgMDECEzMAAz/LZbJZacV+llwAAAADP8swDQYJYIZIAWUDBAIBBQCggcgwGQYJ
# KoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQB
# gjcCARUwLwYJKoZIhvcNAQkEMSIEICpXe3RS3b2coD0CJveEHlglqtPUYZ2FqSrO
# UfP6C6Y4MFwGCisGAQQBgjcCAQwxTjBMoEaARABCAHUAaQBsAHQAOgAgAFIAZQBs
# AGUAYQBzAGUAXwB2ADMALgAxADMALgAzAF8AMgAwADIANQAwADQAMAA4AC4AMAAx
# oQKAADANBgkqhkiG9w0BAQEFAASCAYAmJYOH2SjWrMmcHJ8vM0m+FXlE4fijQrFJ
# fu30sRGW2+bp7yk+caUm5hyHwiR9Yama6awchtCUoZDNzG7FcU5mUFDOc0zXahRO
# 827JHVOP7/IalfnwG90RxeCYgF1C94hSahjR7vp0GkcgBkiLTWIPeoQr77B44kSs
# zrU+VHe+09texTrjyure57Znv1zX/smzf+S+xmaARBQPs0KmEkXb/oZIFGmRa28E
# izT1GEmD/UILvgUWPqGtthKkQOnTf/lBmCqwgRJweJMPsDEBMV0aZ8Mk2QWaeHRs
# WvXSdi+pnjqyuZAsBfZQBGsohljPj40pxObN+LiIXXOD+c0fsKiYOrgf+p3dVmIT
# /oBOWTpMbLzos8x0+VKLfdyiWDosR5+OxBCD41jrsoImx2YKE5HMl7NmTLQjiPri
# vewwJnLtXiBesrRdKiNuX2hA06iKBU7ybx79957ZdGnlVfu8pUG/eYeaEEg8JVfs
# KeUyUEvx5o9pIXN/q6Ck6qiO6ro/KC2hghSgMIIUnAYKKwYBBAGCNwMDATGCFIww
# ghSIBgkqhkiG9w0BBwKgghR5MIIUdQIBAzEPMA0GCWCGSAFlAwQCAQUAMIIBYQYL
# KoZIhvcNAQkQAQSgggFQBIIBTDCCAUgCAQEGCisGAQQBhFkKAwEwMTANBglghkgB
# ZQMEAgEFAAQgre4NFOuyvohP31cSYreVl1z+fKYtwevUr+VMN2PhSv4CBmfYFLw9
# ihgTMjAyNTA0MDgxNTQyNTguOTg1WjAEgAIB9KCB4KSB3TCB2jELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFt
# ZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046M0RBNS05
# NjNCLUUxRjQxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWUgU3Rh
# bXBpbmcgQXV0aG9yaXR5oIIPIDCCB4IwggVqoAMCAQICEzMAAAAF5c8P/2YuyYcA
# AAAAAAUwDQYJKoZIhvcNAQEMBQAwdzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjFIMEYGA1UEAxM/TWljcm9zb2Z0IElkZW50aXR5
# IFZlcmlmaWNhdGlvbiBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDIwMB4X
# DTIwMTExOTIwMzIzMVoXDTM1MTExOTIwNDIzMVowYTELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0
# IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCefOdSY/3gxZ8FfWO1BiKjHB7X55cz0RMFvWVGR3eR
# wV1wb3+yq0OXDEqhUhxqoNv6iYWKjkMcLhEFxvJAeNcLAyT+XdM5i2CgGPGcb95W
# JLiw7HzLiBKrxmDj1EQB/mG5eEiRBEp7dDGzxKCnTYocDOcRr9KxqHydajmEkzXH
# OeRGwU+7qt8Md5l4bVZrXAhK+WSk5CihNQsWbzT1nRliVDwunuLkX1hyIWXIArCf
# rKM3+RHh+Sq5RZ8aYyik2r8HxT+l2hmRllBvE2Wok6IEaAJanHr24qoqFM9WLeBU
# Sudz+qL51HwDYyIDPSQ3SeHtKog0ZubDk4hELQSxnfVYXdTGncaBnB60QrEuazvc
# ob9n4yR65pUNBCF5qeA4QwYnilBkfnmeAjRN3LVuLr0g0FXkqfYdUmj1fFFhH8k8
# YBozrEaXnsSL3kdTD01X+4LfIWOuFzTzuoslBrBILfHNj8RfOxPgjuwNvE6YzauX
# i4orp4Sm6tF245DaFOSYbWFK5ZgG6cUY2/bUq3g3bQAqZt65KcaewEJ3ZyNEobv3
# 5Nf6xN6FrA6jF9447+NHvCjeWLCQZ3M8lgeCcnnhTFtyQX3XgCoc6IRXvFOcPVrr
# 3D9RPHCMS6Ckg8wggTrtIVnY8yjbvGOUsAdZbeXUIQAWMs0d3cRDv09SvwVRd61e
# vQIDAQABo4ICGzCCAhcwDgYDVR0PAQH/BAQDAgGGMBAGCSsGAQQBgjcVAQQDAgEA
# MB0GA1UdDgQWBBRraSg6NS9IY0DPe9ivSek+2T3bITBUBgNVHSAETTBLMEkGBFUd
# IAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsGAQUFBwMIMBkGCSsG
# AQQBgjcUAgQMHgoAUwB1AGIAQwBBMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgw
# FoAUyH7SaoUqG8oZmAQHJ89QEE9oqKIwgYQGA1UdHwR9MHsweaB3oHWGc2h0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElkZW50
# aXR5JTIwVmVyaWZpY2F0aW9uJTIwUm9vdCUyMENlcnRpZmljYXRlJTIwQXV0aG9y
# aXR5JTIwMjAyMC5jcmwwgZQGCCsGAQUFBwEBBIGHMIGEMIGBBggrBgEFBQcwAoZ1
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQl
# MjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0ZSUy
# MEF1dGhvcml0eSUyMDIwMjAuY3J0MA0GCSqGSIb3DQEBDAUAA4ICAQBfiHbHfm21
# WhV150x4aPpO4dhEmSUVpbixNDmv6TvuIHv1xIs174bNGO/ilWMm+Jx5boAXrJxa
# gRhHQtiFprSjMktTliL4sKZyt2i+SXncM23gRezzsoOiBhv14YSd1Klnlkzvgs29
# XNjT+c8hIfPRe9rvVCMPiH7zPZcw5nNjthDQ+zD563I1nUJ6y59TbXWsuyUsqw7w
# XZoGzZwijWT5oc6GvD3HDokJY401uhnj3ubBhbkR83RbfMvmzdp3he2bvIUztSOu
# FzRqrLfEvsPkVHYnvH1wtYyrt5vShiKheGpXa2AWpsod4OJyT4/y0dggWi8g/tgb
# hmQlZqDUf3UqUQsZaLdIu/XSjgoZqDjamzCPJtOLi2hBwL+KsCh0Nbwc21f5xvPS
# wym0Ukr4o5sCcMUcSy6TEP7uMV8RX0eH/4JLEpGyae6Ki8JYg5v4fsNGif1OXHJ2
# IWG+7zyjTDfkmQ1snFOTgyEX8qBpefQbF0fx6URrYiarjmBprwP6ZObwtZXJ23jK
# 3Fg/9uqM3j0P01nzVygTppBabzxPAh/hHhhls6kwo3QLJ6No803jUsZcd4JQxiYH
# Hc+Q/wAMcPUnYKv/q2O444LO1+n6j01z5mggCSlRwD9faBIySAcA9S8h22hIAcRQ
# qIGEjolCK9F6nK9ZyX4lhthsGHumaABdWzCCB5YwggV+oAMCAQICEzMAAABGF+R1
# esr92uUAAAAAAEYwDQYJKoZIhvcNAQEMBQAwYTELMAkGA1UEBhMCVVMxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwHhcNMjQxMTI2MTg0ODQ5WhcN
# MjUxMTE5MTg0ODQ5WjCB2jELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQG
# A1UECxMdVGhhbGVzIFRTUyBFU046M0RBNS05NjNCLUUxRjQxNTAzBgNVBAMTLE1p
# Y3Jvc29mdCBQdWJsaWMgUlNBIFRpbWUgU3RhbXBpbmcgQXV0aG9yaXR5MIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAsJV86I/zDS9QX51foIOHdH2bptR3
# VCYnUjU3A86Ryb5iAah+euswWHFdE8je/t6jpyY6aE8eiQTIDWJy+QZk1/R65l9F
# nTTC3++LuzbQUrgA9rH+p9qlFK8+4vH+69CYmYsSiZ5LwP9WpCx6aUDAwroNaAtA
# GI3e+d2+b8tb1nax1xPYS+9QWXuQwquf+CwZ8vGjkGZc743sIDjZImZvkn3LZCY4
# fS8XZA5auRLxhOmFNLgt+1xe6pB7yJLA9vl4AT9JRDH5jyaNnyPRcCAPWDF+yiCD
# RDOTmOp5Lyq8jPbOWyui1eM+PDWKYiNcbx9eWA6bPtfZxwrSjFU2XQeHGIQNHVai
# e3QLuFXMVMA9QBHDMVmyDkdc+jhZFWPRl+aB/JNe3fbd+T1n59F7sVuEhv64poLR
# YKRP7IUbMuZzAmx8ngnVtB3taZa2EKk7Ehz9p/5c9gwoCJZ8frrzy1X+fiRv9XdY
# vy3cGwtlh+lBBCcmSJd2tGMDOK3c6Efj+HTvSP9qFjsVwmKhcrWHQsvZYxC1MG8i
# 4640XXbXkfEE8awn2nSqSnxWOgJPxzWT1B2gD2pN22jiL1e0PGsaNw1kMtom9811
# eoTDzbdb/dKb/qvXWkHcFM1K4HG8E4Xa0YVh8JUSFYNrEeuvBz5+P/JfYpBqJKy+
# oAJlcTbMBGfWsAsCAwEAAaOCAcswggHHMB0GA1UdDgQWBBQRNtDUr3awumenJukT
# xj/GG6iK8TAfBgNVHSMEGDAWgBRraSg6NS9IY0DPe9ivSek+2T3bITBsBgNVHR8E
# ZTBjMGGgX6BdhltodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9N
# aWNyb3NvZnQlMjBQdWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmclMjBDQSUyMDIw
# MjAuY3JsMHkGCCsGAQUFBwEBBG0wazBpBggrBgEFBQcwAoZdaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBQdWJsaWMlMjBS
# U0ElMjBUaW1lc3RhbXBpbmclMjBDQSUyMDIwMjAuY3J0MAwGA1UdEwEB/wQCMAAw
# FgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMGYGA1UdIARf
# MF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAIBgZngQwBBAIw
# DQYJKoZIhvcNAQEMBQADggIBABSFuS/oBs1+IMh6K0t92Cl7ivYgvdYmU6Zt9Mfx
# HRxulPDQLtqorcsY2VaujA6t9NILKRtJ7cy2KlYY35Lu4jcxO/JOrTYBQq/cLxpC
# B3ivkNkQDvf7OUfK4TQvpcsDgfuiuWYtJHztGoFV3+zZNjuheg/QBMzS4oxvnDnu
# RH9heZeGbFUpCxQiOYxCwvq+CpzWY7p3Pqr40s9g5DbF364xYcpPiu7+1O/iRWfJ
# GefMhbsRF9HMQyqSS8YjYfzgwji9lMWJIcnyNwEdBIX8V/UGR1YMcmcJ2r0d+Rca
# i0ohk3gCbCu2Dd2yMcrj+ngnJ5F/EzHabvZDw/e7B5zO6aNFEA642je3rb4iw8Z2
# sdp3pnbyVtwXsDixaw9Z0p3e2R3Txjwd6Fkwmivf918EBES4t14/h2XPPUT+dDbe
# 4e/txuqKtpF2DYnSPYlnfoC/pb5EGR/WEyHwQi1o77l71FFFPgLxSNNFLaq73ayH
# aghWqhPRx0IEn13kOd8S1nTAs7VD/2JzF4icTQZHOlBNqcf6Ovvy1yQyKcCF0eB0
# qHS35H7DUJehRaydcbDmBkh73BZB/N/PUZlL6469TQW3XrHOAbuJKMft3GmzmXNc
# 5vPRvtUUS9rUXhc0jJWEhjt4ip9xhl5kIkZhZQW9wqW1FUM/n4MVTH3i9I+C5ikH
# 09YyMYID1DCCA9ACAQEweDBhMQswCQYDVQQGEwJVUzEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUHVibGljIFJTQSBU
# aW1lc3RhbXBpbmcgQ0EgMjAyMAITMwAAAEYX5HV6yv3a5QAAAAAARjANBglghkgB
# ZQMEAgEFAKCCAS0wGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3
# DQEJBDEiBCDPdRvjT8qK4PTs6+ghOBL1RDcKeox2y4SaKqT38Hbu1jCB3QYLKoZI
# hvcNAQkQAi8xgc0wgcowgccwgaAEIBIndkiaVD4+cUJu9zOL6g5lYdUEek4rk1FZ
# C9z/ForOMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVz
# dGFtcGluZyBDQSAyMDIwAhMzAAAARhfkdXrK/drlAAAAAABGMCIEIFaeiNWATDJ4
# tKwrg+e7xCv7c1mcqR6lhYpFixVWNdUcMA0GCSqGSIb3DQEBCwUABIICAA28fFPH
# LgYk/MnopPa0fS75EWeZHz/gT/OtHkRlb3MnfivyaS4MNU9CH+6ml7PZ4cv5W2KB
# sKGF+VPpgymUnyoBmqLhCqjqjkzmztOp51pc095aUylQYF7TDQQRR/5gtxPfNEom
# SYV8A98tJh3SlaHhRYrffKMEjqVQEjBBPQDqVxb2WdiQddWf6BuMz0UACnivMyqj
# vWb61w8hql9hO3kcAIX+bymiog28zvlns5j9lVV3RrhNLMvRjGEJv8MbOihmcXrc
# FIWX/BoWQihs12VnzF+qWqVIb57NtX6UeCrX3WNQ8YvF9YcmsNQuDUnC70bTiOWs
# PN8SumxLgTtMlCGY83WfIF4hRbObOjezw9XuWfeC0sjs2mjCWLvp4Yv0zKEblJYN
# I11K6sw419s/4HVQFfJPUGQ8LJULOD4rS/EZwOEVen69pfFb9rdJQOuqKIJvWeX1
# Wu+Jd7yHry7lJN9Epw/Jeu8JvmRILNjphrKafcMC2mXQSyHbMtbP6ACkJyUvzl9K
# TxY/YHdm80Qf3qxfpzwRBI6Aw0wrO57hazCd776HOvcbGcCEuDl4DsMhm1K5dJsk
# uS4DHKNA1h62ulEs35PGeCSf3gy3H32Gz7Z2ACwcY7Yx3LzEEdgUrZeMdbCebqTp
# KSoKbGk2swORBs9MDBOVT7lrYHgF16kyku6S
# SIG # End signature block
