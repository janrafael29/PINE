<#

.SYNOPSIS

  Quick launcher: mirror your Android phone (wraps scrcpy_phone.ps1).



.EXAMPLE

  .\scripts\view_phone.ps1

.EXAMPLE

  .\scripts\view_phone.ps1 -Serial 10944373AB107405

.EXAMPLE

  .\scripts\view_phone.ps1 -List

#>

param(

    [string]$Serial = "",

    [int]$MaxSize = 0,

    [switch]$NoStayAwake,

    [switch]$List

)



& "$PSScriptRoot\scrcpy_phone.ps1" @PSBoundParameters

