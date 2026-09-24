<#
.SYNOPSIS
  Instala os agents e skills de Code Review (marlabs-code-review) na pasta .github/ do projeto.

.DESCRIPTION
  Copia o pacote para os mesmos caminhos usados pelo POC:
    .github/agents/        (2 agents)
    .github/skills/        (skills)
    .github/code-review/   (CHANGELOG.md e review-decisions.md)

  Cuidados:
    - Confere o SHA256SUMS do pacote antes de copiar e os arquivos instalados depois de copiar.
    - Nunca sobrescreve .github/code-review/review-decisions.md (decisoes do time).
    - Se ja houver uma versao instalada, mostra as versoes e pede confirmacao antes de substituir.
    - Nao altera nada fora de .github/agents, .github/skills e .github/code-review.
    - Nao faz commit: o time revisa e comita a alteracao.

.EXAMPLE
  # A partir de um clone do repositorio do marketplace
  .\install.ps1 -Target C:\caminho\do\projeto

.EXAMPLE
  # Remoto, executado na raiz do projeto
  irm https://raw.githubusercontent.com/code-review/v1.0.0/install.ps1 | iex
#>
[CmdletBinding()]
param(
    # Pasta do marketplace (raiz deste repositorio). Se omitida, usa a pasta do script ou clona -Repo/-Ref.
    [string]$Source = '',
    # Repositorio do marketplace (code-review ou URL git). Usado somente quando nao ha pacote local.
    [string]$Repo = 'code-review',
    # Tag ou branch a instalar.
    [string]$Ref = 'v1.0.0',
    # Projeto de destino (qualquer pasta dentro de um repositorio git).
    [string]$Target = '',
    # Confirma a substituicao de arquivos existentes sem perguntar.
    [switch]$Yes,
    # Mostra o que seria feito, sem alterar nada.
    [switch]$DryRun
)

function Invoke-MarlabsCodeReviewInstall {
    param([string]$Source, [string]$Repo, [string]$Ref, [string]$Target, [bool]$Yes, [bool]$DryRun, [string]$ScriptRoot, [bool]$RemoteRequested)

    $ErrorActionPreference = 'Stop'
    $pluginRel = 'plugins/marlabs-code-review'
    $tempClone = $null

    function Get-Sha256([string]$Path) {
        (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    }

    function Get-PackageVersion([string]$CorePath) {
        if (-not (Test-Path -LiteralPath $CorePath)) { return $null }
        $text = [IO.File]::ReadAllText($CorePath, [Text.Encoding]::UTF8)
        $m = [regex]::Match($text, 'do pacote: ([^*\r\n]+)\*\*')
        if ($m.Success) { return $m.Groups[1].Value.Trim() }
        return 'desconhecida'
    }

    function Get-DestinationPath([string]$Rel) {
        if ($Rel -match '^com\.github\.copilot/agents/(.+)\.agent\.md$') { return ".github/agents/$($Matches[1]).md" }
        if ($Rel -like 'skills/*') { return ".github/$Rel" }
        if ($Rel -like 'code-review/*') { return ".github/$Rel" }
        throw "Arquivo inesperado no SHA256SUMS: $Rel"
    }

    try {
        # 1. Projeto de destino
        if ([string]::IsNullOrEmpty($Target)) { $Target = (Get-Location).Path }
        if (-not (Test-Path -LiteralPath $Target -PathType Container)) { throw "Pasta de destino nao encontrada: $Target" }
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'git nao encontrado no PATH.' }
        # No Windows PowerShell 5.1, stderr de comando nativo com ErrorActionPreference=Stop vira erro fatal.
        $ErrorActionPreference = 'Continue'
        $root = (& git -C $Target rev-parse --show-toplevel 2>$null)
        $gitExit = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        if ($gitExit -ne 0 -or [string]::IsNullOrEmpty($root)) {
            throw "O destino nao esta dentro de um repositorio git: $Target. Os agents dependem do git para calcular o Change Set."
        }
        $root = [IO.Path]::GetFullPath($root)

        # 2. Origem do pacote
        # -Repo/-Ref explicitos sempre baixam do repositorio; sem eles, usa o pacote ao lado do script.
        if ([string]::IsNullOrEmpty($Source) -and -not $RemoteRequested -and -not [string]::IsNullOrEmpty($ScriptRoot) -and
            (Test-Path -LiteralPath (Join-Path $ScriptRoot "$pluginRel/plugin.json"))) {
            $Source = $ScriptRoot
        }
        if ([string]::IsNullOrEmpty($Source)) {
            if ($Repo -eq 'code-review') {
                throw 'Repositorio do marketplace nao configurado. Informe -Repo code-review ou -Source <pasta do marketplace>.'
            }
            $url = $Repo
            if ($Repo -notmatch '[:@]' -and $Repo -notlike '*.git') { $url = "https://github.com/$Repo.git" }
            $tempClone = Join-Path ([IO.Path]::GetTempPath()) ("marlabs-code-review-" + [guid]::NewGuid().ToString('N'))
            Write-Host "Baixando $url ($Ref)..."
            & git -c core.autocrlf=false clone --quiet --depth 1 --branch $Ref $url $tempClone
            if ($LASTEXITCODE -ne 0) { throw "Falha ao clonar $url na referencia $Ref." }
            $Source = $tempClone
        }
        $pkg = Join-Path $Source $pluginRel
        $sumsFile = Join-Path $Source 'SHA256SUMS'
        if (-not (Test-Path -LiteralPath (Join-Path $pkg 'plugin.json'))) { throw "Pacote nao encontrado em: $pkg" }
        if (-not (Test-Path -LiteralPath $sumsFile)) { throw "SHA256SUMS nao encontrado em: $Source" }

        # 3. Conferencia do pacote
        $entries = @()
        foreach ($line in [IO.File]::ReadAllLines($sumsFile)) {
            $line = $line.Trim()
            if ($line -eq '') { continue }
            $m = [regex]::Match($line, '^([0-9a-fA-F]{64}) [ *]?(.+)$')
            if (-not $m.Success) { throw "Linha invalida no SHA256SUMS: $line" }
            $rel = $m.Groups[2].Value
            $srcPath = Join-Path $pkg $rel
            if (-not (Test-Path -LiteralPath $srcPath)) {
                $hint = ''
                if ($srcPath.Length -ge 260) { $hint = ' (caminho com mais de 260 caracteres: mova o pacote para uma pasta com caminho mais curto)' }
                throw "Arquivo do pacote ausente: $rel$hint"
            }
            $hash = $m.Groups[1].Value.ToLowerInvariant()
            if ((Get-Sha256 $srcPath) -ne $hash) { throw "Hash divergente no pacote: $rel. O download pode estar corrompido." }
            $entries += [pscustomobject]@{ Rel = $rel; Src = $srcPath; Dst = (Get-DestinationPath $rel); Hash = $hash }
        }
        if ($entries.Count -eq 0) { throw 'SHA256SUMS vazio.' }

        $pluginVersion = (Get-Content -LiteralPath (Join-Path $pkg 'plugin.json') -Raw -Encoding UTF8 | ConvertFrom-Json).version
        $newVersion = Get-PackageVersion (Join-Path $pkg 'skills/code-review-core/SKILL.md')
        $oldVersion = Get-PackageVersion (Join-Path $root '.github/skills/code-review-core/SKILL.md')

        # 4. Plano
        $plan = @()
        foreach ($e in $entries) {
            $dstPath = Join-Path $root $e.Dst
            $action = 'criar'
            if (Test-Path -LiteralPath $dstPath) {
                if ($e.Dst -eq '.github/code-review/review-decisions.md') { $action = 'manter' }
                elseif ((Get-Sha256 $dstPath) -eq $e.Hash) { $action = 'igual' }
                else { $action = 'substituir' }
            }
            $plan += [pscustomobject]@{ Acao = $action; Destino = $e.Dst; Src = $e.Src; DstPath = $dstPath; Hash = $e.Hash }
        }

        Write-Host ''
        Write-Host "Projeto:            $root"
        Write-Host "Pacote (plugin):    $pluginVersion"
        Write-Host "Versao das regras:  $newVersion"
        if ($oldVersion) { Write-Host "Versao instalada:   $oldVersion" } else { Write-Host 'Versao instalada:   nenhuma' }
        Write-Host ''
        foreach ($p in $plan) { Write-Host ("  {0,-11} {1}" -f $p.Acao, $p.Destino) }
        Write-Host ''

        $toWrite = @($plan | Where-Object { $_.Acao -eq 'criar' -or $_.Acao -eq 'substituir' })
        $toReplace = @($plan | Where-Object { $_.Acao -eq 'substituir' })

        if ($toWrite.Count -eq 0) {
            Write-Host 'Nada a fazer: o pacote ja esta instalado nesta versao.'
            return $true
        }
        if ($DryRun) {
            Write-Host 'Simulacao (-DryRun): nenhum arquivo foi alterado.'
            return $true
        }
        if ($toReplace.Count -gt 0 -and -not $Yes) {
            if ([Console]::IsInputRedirected) {
                throw "$($toReplace.Count) arquivo(s) seriam substituidos. Execute novamente com -Yes para confirmar."
            }
            $answer = Read-Host "$($toReplace.Count) arquivo(s) existentes serao substituidos. Continuar? (s/N)"
            if ($answer -notmatch '^(s|sim|y|yes)$') {
                Write-Host 'Instalacao cancelada. Nenhum arquivo foi alterado.'
                return $true
            }
        }

        # 5. Copia
        foreach ($p in $toWrite) {
            $dir = Split-Path -Parent $p.DstPath
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            Copy-Item -LiteralPath $p.Src -Destination $p.DstPath -Force
        }

        # 6. Conferencia da instalacao
        foreach ($p in $toWrite) {
            if ((Get-Sha256 $p.DstPath) -ne $p.Hash) { throw "Hash divergente apos a copia: $($p.Destino)" }
        }

        Write-Host "Instalado com sucesso: $($toWrite.Count) arquivo(s) gravado(s) e conferido(s)."
        Write-Host ''
        Write-Host 'Proximos passos (revisar e comitar):'
        Write-Host '  git status -- .github'
        Write-Host "  git checkout -b chore/code-review-$newVersion"
        Write-Host '  git add .github/agents .github/skills .github/code-review'
        Write-Host "  git commit -m `"chore: instala Code Review $newVersion`""
        return $true
    }
    catch {
        Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    finally {
        if ($tempClone -and (Test-Path -LiteralPath $tempClone)) {
            Remove-Item -LiteralPath $tempClone -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

$ok = Invoke-MarlabsCodeReviewInstall -Source $Source -Repo $Repo -Ref $Ref -Target $Target `
    -Yes:$Yes.IsPresent -DryRun:$DryRun.IsPresent -ScriptRoot $PSScriptRoot `
    -RemoteRequested ($PSBoundParameters.ContainsKey('Repo') -or $PSBoundParameters.ContainsKey('Ref'))

# Codigo de saida somente quando executado como arquivo; via "irm | iex" um exit fecharia o terminal do usuario.
if ($PSCommandPath -and -not $ok) { exit 1 }
