# MVP Mode Management Script for Windows
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("on", "off", "status", "enable", "disable")]
    [string]$Action
)

function Set-MVPMode {
    param([bool]$Enable)
    
    $envFile = ".env"
    if (-not (Test-Path $envFile)) {
        Write-Host "❌ .env file not found!" -ForegroundColor Red
        return $false
    }
    
    $content = Get-Content $envFile
    $newValue = if ($Enable) { "MVP_MODE=true" } else { "MVP_MODE=false" }
    
    # Check if MVP_MODE exists
    $mvpLineExists = $content | Where-Object { $_ -match "^MVP_MODE=" }
    
    if ($mvpLineExists) {
        # Replace existing line
        $content = $content -replace "^MVP_MODE=.*", $newValue
    } else {
        # Add new line
        $content += $newValue
    }
    
    Set-Content -Path $envFile -Value $content
    return $true
}

function Get-MVPStatus {
    $envFile = ".env"
    if (-not (Test-Path $envFile)) {
        Write-Host "⚠️  .env file not found!" -ForegroundColor Yellow
        return
    }
    
    $content = Get-Content $envFile
    $mvpLine = $content | Where-Object { $_ -match "^MVP_MODE=" }
    
    Write-Host "🎯 MVP Mode Status:" -ForegroundColor Blue
    
    if ($mvpLine -match "MVP_MODE=true") {
        Write-Host "✅ MVP Mode: ENABLED (using mock data)" -ForegroundColor Green
    } elseif ($mvpLine -match "MVP_MODE=false") {
        Write-Host "❌ MVP Mode: DISABLED (using real APIs)" -ForegroundColor Red
    } else {
        Write-Host "⚠️  MVP Mode: NOT SET (defaulting to real APIs)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Blue
    Write-Host "  .\mvp-mode.ps1 on       - Enable MVP mode"
    Write-Host "  .\mvp-mode.ps1 off      - Disable MVP mode"
    Write-Host "  .\mvp-mode.ps1 status   - Check current status"
    Write-Host "  .\mvp-mode.ps1 enable   - Enable MVP + restart services"
    Write-Host "  .\mvp-mode.ps1 disable  - Disable MVP + restart services"
}

switch ($Action) {
    "on" {
        Write-Host "🎯 Enabling MVP Mode (mock data)..." -ForegroundColor Blue
        if (Set-MVPMode -Enable $true) {
            Write-Host "✅ MVP Mode enabled" -ForegroundColor Green
            Write-Host "ℹ️  System will use mock data instead of real APIs" -ForegroundColor Cyan
            Write-Host "🔄 Restart services: make restart" -ForegroundColor Yellow
        }
    }
    
    "off" {
        Write-Host "🎯 Disabling MVP Mode (real API data)..." -ForegroundColor Blue
        if (Set-MVPMode -Enable $false) {
            Write-Host "✅ MVP Mode disabled" -ForegroundColor Green
            Write-Host "ℹ️  System will use real Alpha Vantage API" -ForegroundColor Cyan
            Write-Host "⚠️  Make sure ALPHA_VANTAGE_API_KEY is set in .env" -ForegroundColor Yellow
            Write-Host "🔄 Restart services: make restart" -ForegroundColor Yellow
        }
    }
    
    "status" {
        Get-MVPStatus
    }
    
    "enable" {
        Write-Host "🎯 Enabling MVP Mode and restarting services..." -ForegroundColor Blue
        if (Set-MVPMode -Enable $true) {
            Write-Host "✅ MVP Mode enabled" -ForegroundColor Green
            Write-Host "🔄 Restarting services..." -ForegroundColor Yellow
            docker-compose restart
            Write-Host "🚀 MVP Mode enabled and services restarted!" -ForegroundColor Green
        }
    }
    
    "disable" {
        Write-Host "🎯 Disabling MVP Mode and restarting services..." -ForegroundColor Blue
        if (Set-MVPMode -Enable $false) {
            Write-Host "✅ MVP Mode disabled" -ForegroundColor Green
            Write-Host "🔄 Restarting services..." -ForegroundColor Yellow
            docker-compose restart
            Write-Host "🚀 MVP Mode disabled and services restarted!" -ForegroundColor Green
        }
    }
}