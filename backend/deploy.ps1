# MetroPaws Backend - Docker Hub Build & Render Deploy Script
#
# Usage (run from the backend/ directory):
#   .\deploy.ps1 -Env dev     # build, push & deploy the DEV service  (.env.dev)
#   .\deploy.ps1 -Env prod    # build, push & deploy the PROD service (.env.prod) - asks for confirmation
#
# Each environment is fully isolated:
#   dev  -> service "metropaws-backend-dev",  image metropaws-backend-dev,  config .env.dev,  id .render-service-id.dev
#   prod -> service "metropaws-backend",      image metropaws-backend,      config .env.prod, id .render-service-id.prod
#
# The env file is the single source of truth for that environment's Render env vars.
# Whatever is in .env.<env> is pushed to the service (a full replace) on every deploy.

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "prod")]
    [string]$Env
)

$ErrorActionPreference = "Stop"

# ── Per-environment configuration ─────────────────────────────────────────────
$DOCKER_USERNAME = "marioogarbo"

switch ($Env) {
    "dev" {
        $IMAGE_NAME          = "metropaws-backend-dev"
        $RENDER_SERVICE_NAME = "metropaws-backend-dev"
        $ENV_FILE            = ".env.dev"
        $SERVICE_ID_FILE     = ".render-service-id.dev"
    }
    "prod" {
        $IMAGE_NAME          = "metropaws-backend"
        $RENDER_SERVICE_NAME = "metropaws-backend"
        $ENV_FILE            = ".env.prod"
        $SERVICE_ID_FILE     = ".render-service-id.prod"
    }
}

$RENDER_REGION = "singapore"       # closest to PH / AU
$RENDER_PLAN   = "free"
$RENDER_PORT   = 8000

$VERSION      = "$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$FULL_IMAGE   = "$DOCKER_USERNAME/$($IMAGE_NAME):$VERSION"
$LATEST_IMAGE = "$DOCKER_USERNAME/$($IMAGE_NAME):latest"

# ── Safety: confirm before touching PROD ──────────────────────────────────────
if ($Env -eq "prod") {
    Write-Host ""
    Write-Host "!! You are about to deploy to PRODUCTION (metropaws-backend - the LIVE app)." -ForegroundColor Red
    Write-Host "   This pushes $ENV_FILE env vars to the live service and redeploys it." -ForegroundColor Red
    $confirm = Read-Host "   Type PROD to continue"
    if ($confirm -cne "PROD") {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 1
    }
}

# ── Read the environment's config file ────────────────────────────────────────
if (-not (Test-Path $ENV_FILE)) {
    Write-Error "$ENV_FILE not found. Create it before deploying $Env."
    exit 1
}

$envMap = @{}
Get-Content $ENV_FILE | ForEach-Object {
    if ($_ -match "^\s*([^#][^=]*?)\s*=\s*(.*)\s*$") {
        $envMap[$matches[1]] = $matches[2]
    }
}

$RENDER_API_KEY = $envMap["RENDER_API_KEY"]
if (-not $RENDER_API_KEY) {
    Write-Error "RENDER_API_KEY is not set in $ENV_FILE"
    exit 1
}

$renderHeaders = @{
    "Authorization" = "Bearer $RENDER_API_KEY"
    "Content-Type"  = "application/json"
    "Accept"        = "application/json"
}

# ── Banner ────────────────────────────────────────────────────────────────────
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "    MetroPaws Backend - Build, Push & Deploy [$($Env.ToUpper())]" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Image   : $FULL_IMAGE"
Write-Host "Latest  : $LATEST_IMAGE"
Write-Host "Service : $RENDER_SERVICE_NAME ($RENDER_REGION)"
Write-Host "Config  : $ENV_FILE"
Write-Host ""

# ── Step 1: Build Docker image ────────────────────────────────────────────────
Write-Host "[1/5] Building Docker image..." -ForegroundColor Cyan
docker build --platform linux/amd64 -t $FULL_IMAGE .
if ($LASTEXITCODE -ne 0) { Write-Error "Docker build failed."; exit 1 }

# ── Step 2: Tag as latest ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "[2/5] Tagging as latest..." -ForegroundColor Cyan
docker tag $FULL_IMAGE $LATEST_IMAGE
if ($LASTEXITCODE -ne 0) { Write-Error "Docker tag failed."; exit 1 }

# ── Step 3: Push both tags to Docker Hub ──────────────────────────────────────
Write-Host ""
Write-Host "[3/5] Pushing to Docker Hub..." -ForegroundColor Cyan
docker push $FULL_IMAGE
if ($LASTEXITCODE -ne 0) { Write-Error "Docker push (versioned) failed."; exit 1 }
docker push $LATEST_IMAGE
if ($LASTEXITCODE -ne 0) { Write-Error "Docker push (latest) failed."; exit 1 }
Write-Host "Docker Hub push complete." -ForegroundColor Green

# ── Step 4: Resolve Render owner ID ──────────────────────────────────────────
Write-Host ""
Write-Host "[4/5] Connecting to Render API..." -ForegroundColor Cyan

$ownersResp = Invoke-RestMethod -Uri "https://api.render.com/v1/owners?limit=1" `
    -Headers $renderHeaders -Method Get
$OWNER_ID = $ownersResp[0].owner.id
if (-not $OWNER_ID) { Write-Error "Could not retrieve Render owner ID."; exit 1 }
Write-Host "Owner ID : $OWNER_ID" -ForegroundColor Gray

# ── Build env var array for Render (full replace from $ENV_FILE) ──────────────
# RENDER_API_KEY is a deploy credential, not an app runtime var, so it is excluded.
$renderEnvKeys = @(
    "DATABASE_URL", "SECRET_KEY", "ALGORITHM", "ACCESS_TOKEN_EXPIRE_MINUTES",
    "UPLOAD_DIR", "BASE_URL", "FRONTEND_URL", "ALLOWED_ORIGINS",
    "SMTP_HOST", "SMTP_PORT", "SMTP_USER", "SMTP_PASSWORD", "EMAIL_FROM_NAME", "EMAIL_FROM",
    # ZeptoMail HTTP API (required in prod: Render free tier blocks SMTP ports)
    "ZEPTOMAIL_TOKEN", "ZEPTOMAIL_API_URL",
    "MAX_FILE_BYTES", "SEED_ADMIN_PASSWORD",
    "SUPABASE_URL", "SUPABASE_SERVICE_KEY", "SUPABASE_BUCKET",
    "REIMBURSEMENT_MAX_CLAIM_PHP",
    "PAYMONGO_SECRET_KEY", "PAYMONGO_WEBHOOK_SECRET",
    "PAYMONGO_SUCCESS_REDIRECT", "PAYMONGO_FAILURE_REDIRECT",
    # Payment receipt (invoice) seller / tax identity — see invoice_utils.py.
    "INVOICE_BUSINESS_NAME", "INVOICE_BUSINESS_ADDRESS", "INVOICE_BUSINESS_TIN",
    "INVOICE_BUSINESS_EMAIL", "INVOICE_BUSINESS_PHONE", "INVOICE_BUSINESS_WEBSITE",
    "INVOICE_BUSINESS_REG_LINE", "INVOICE_DOC_TITLE", "INVOICE_VAT_PERCENT"
)
$envVarList = @()
foreach ($key in $renderEnvKeys) {
    if ($envMap.ContainsKey($key)) {
        $envVarList += @{ key = $key; value = $envMap[$key] }
    }
}

# ── Step 5: Create service or trigger redeploy ────────────────────────────────
Write-Host ""
Write-Host "[5/5] Deploying to Render..." -ForegroundColor Cyan

if (Test-Path $SERVICE_ID_FILE) {
    # ── Existing service: update env vars then redeploy ───────────────────────
    $SERVICE_ID = (Get-Content $SERVICE_ID_FILE).Trim()
    Write-Host "Found existing service: $SERVICE_ID" -ForegroundColor Gray

    # Update environment variables (full replace from $ENV_FILE)
    $envBody = $envVarList | ConvertTo-Json -Depth 3
    Invoke-RestMethod `
        -Uri "https://api.render.com/v1/services/$SERVICE_ID/env-vars" `
        -Headers $renderHeaders -Method Put -Body $envBody | Out-Null

    # Trigger redeploy
    $deployBody = @{ clearCache = "do_not_clear" } | ConvertTo-Json
    $deployResp = Invoke-RestMethod `
        -Uri "https://api.render.com/v1/services/$SERVICE_ID/deploys" `
        -Headers $renderHeaders -Method Post -Body $deployBody

    Write-Host "Redeploy triggered. Deploy ID: $($deployResp.id)" -ForegroundColor Green

} else {
    # ── New service: create it ────────────────────────────────────────────────
    Write-Host "No existing service found. Creating new Render service '$RENDER_SERVICE_NAME'..." -ForegroundColor Yellow

    $createBody = @{
        autoDeploy     = "no"
        name           = $RENDER_SERVICE_NAME
        ownerId        = $OWNER_ID
        type           = "web_service"
        image          = @{
            ownerId   = $OWNER_ID
            imagePath = "docker.io/$LATEST_IMAGE"
        }
        serviceDetails = @{
            env             = "image"
            plan            = $RENDER_PLAN
            region          = $RENDER_REGION
            numInstances    = 1
            healthCheckPath = "/health"
        }
        envVars = $envVarList
    } | ConvertTo-Json -Depth 5

    $createResp = Invoke-RestMethod `
        -Uri "https://api.render.com/v1/services" `
        -Headers $renderHeaders -Method Post -Body $createBody

    $SERVICE_ID = $createResp.service.id
    $SERVICE_URL = $createResp.service.serviceDetails.url

    # Save service ID for future deploys
    $SERVICE_ID | Out-File -FilePath $SERVICE_ID_FILE -Encoding utf8 -NoNewline

    Write-Host "Service created: $SERVICE_ID" -ForegroundColor Green
    Write-Host "Service URL    : $SERVICE_URL" -ForegroundColor Green
    Write-Host ""
    Write-Host "ACTION REQUIRED:" -ForegroundColor Yellow
    Write-Host "  Update BASE_URL (and PAYMONGO_*_REDIRECT) in $ENV_FILE to: $SERVICE_URL" -ForegroundColor Yellow
    Write-Host "  Then re-run: .\deploy.ps1 -Env $Env" -ForegroundColor Yellow
}

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "             Deployment Complete! [$($Env.ToUpper())]" -ForegroundColor Green
Write-Host ""
Write-Host "Versioned image : $FULL_IMAGE" -ForegroundColor Green
Write-Host "Latest image    : $LATEST_IMAGE" -ForegroundColor Green
Write-Host ""
Write-Host "Monitor deploy at:" -ForegroundColor Yellow
Write-Host "  https://dashboard.render.com/web/$SERVICE_ID" -ForegroundColor Yellow
Write-Host "========================================================" -ForegroundColor Green
