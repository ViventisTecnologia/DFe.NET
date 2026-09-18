#Requires -Version 5.1
<#
.SYNOPSIS
  Compila o DFe.NET em Release e gera os .nupkg locais (igual ao CI).

.EXAMPLE
  .\pack-local.ps1
  .\pack-local.ps1 -Packages NFe,CTe
  .\pack-local.ps1 -Version 2026.09.01.1630 -OutputDir C:\nuget-local
#>
[CmdletBinding()]
param(
    [string] $Version = (Get-Date -Format "yyyy.MM.dd.HHmm"),
    [string] $OutputDir = (Join-Path $PSScriptRoot "nupkgs"),
    [ValidateSet("NFe", "CTe", "MDFe", "Danfe")]
    [string[]] $Packages = @("NFe", "CTe", "MDFe", "Danfe"),
    [string] $Configuration = "Release"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Invoke-Dotnet {
    param([string[]] $DotnetArgs)
    Write-Host "dotnet $($DotnetArgs -join ' ')" -ForegroundColor Cyan
    & dotnet @DotnetArgs
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet falhou (exit $LASTEXITCODE): $($DotnetArgs -join ' ')"
    }
}

function Build-Projects {
    param([string[]] $Projects)
    foreach ($project in $Projects) {
        Invoke-Dotnet @(
            "build", $project,
            "-c", $Configuration,
            "-p:Version=$Version",
            "--nologo"
        )
    }
}

function Pack-Project {
    param([string] $Project)
    Invoke-Dotnet @(
        "pack", $Project,
        "-o", $OutputDir,
        "-c", $Configuration,
        "-v", "minimal",
        "-p:NuspecProperties=version=$Version",
        "-p:PackageVersion=$Version",
        "--nologo"
    )
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
Write-Host "Versao: $Version" -ForegroundColor Green
Write-Host "Saida:  $OutputDir" -ForegroundColor Green

# NFe/CTe/MDFe usam nuspec com NoBuild=true: o pack so empacota DLLs ja compiladas.
$precisaBase = $Packages | Where-Object { $_ -in @("NFe", "CTe", "MDFe") }
if ($precisaBase) {
    Build-Projects @(
        "DFe.Classes\DFe.Classes.csproj",
        "DFe.Utils\DFe.Utils.csproj",
        "DFe.Wsdl\DFe.Wsdl.csproj"
    )
}

if ($Packages -contains "NFe") {
    Build-Projects @(
        "NFe.Classes\NFe.Classes.csproj",
        "NFe.Servicos\NFe.Servicos.csproj",
        "NFe.Utils\NFe.Utils.csproj",
        "NFe.Wsdl\NFe.Wsdl.csproj",
        "NFe.Wsdl.Standard\NFe.Wsdl.Standard.csproj"
    )
    Pack-Project "NuGet\Zeus.Net.NFe.NFCe\Zeus.Net.NFe.NFCe.csproj"
}

if ($Packages -contains "CTe") {
    Build-Projects @(
        "CTe.Classes\CTe.Classes.csproj",
        "CTe.Servicos\CTe.Servicos.csproj",
        "CTe.Utils\CTe.Utils.csproj",
        "CTe.Wsdl\CTe.Wsdl.csproj"
    )
    Pack-Project "NuGet\Zeus.Net.CTe\Zeus.Net.CTe.csproj"
}

if ($Packages -contains "MDFe") {
    Build-Projects @(
        "MDFe.Classes\MDFe.Classes.csproj",
        "MDFe.Servicos\MDFe.Servicos.csproj",
        "MDFe.Utils\MDFe.Utils.csproj",
        "MDFe.Wsdl\MDFe.Wsdl.csproj"
    )
    Pack-Project "NuGet\Zeus.Net.MDFe\Zeus.Net.MDFe.csproj"
}

if ($Packages -contains "Danfe") {
    Pack-Project "NFe.Danfe.Html\NFe.Danfe.Html.csproj"
    Pack-Project "NFe.Danfe.QuestPdf\NFe.Danfe.QuestPdf.csproj"
    Pack-Project "NFe.Danfe.PdfClown\NFe.Danfe.PdfClown.csproj"
}

Write-Host ""
Write-Host "Pacotes gerados:" -ForegroundColor Green
Get-ChildItem $OutputDir -Filter "*.nupkg" | ForEach-Object { Write-Host "  $($_.FullName)" }

Write-Host ""
Write-Host "No outro projeto:" -ForegroundColor Yellow
Write-Host "  dotnet add package Zeus.Net.NFe.NFCe --source `"$OutputDir`" --version $Version"
