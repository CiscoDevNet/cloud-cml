@echo off
REM This file is part of Cisco Modeling Labs
REM Copyright (c) 2019-2024, Cisco Systems, Inc.
REM All rights reserved.

setlocal EnableDelayedExpansion

REM Change to script directory
cd /d "%~dp0"

:ask_yes_no
set "prompt=%~1"
set "default=%~2"
:ask_loop
set /p "answer=%prompt% "
if "!answer!"=="" set "answer=%default%"
for %%A in (yes y true 1) do if /i "!answer!"=="%%A" exit /b 0
for %%A in (no n false 0) do if /i "!answer!"=="%%A" exit /b 1
echo Please answer yes or no.
goto ask_loop

:generate_random_prefix
REM Generate random 8 character string (lowercase alphanumeric)
set "prefix="
set "chars=abcdefghijklmnopqrstuvwxyz0123456789"
for /L %%i in (1,1,8) do (
    set /a "rand=!random! %% 36"
    for %%j in (!rand!) do set "prefix=!prefix!!chars:~%%j,1!"
)
exit /b

:validate_prefix
set "prefix=%~1"
echo !prefix! | findstr /r "^[a-z0-9][a-z0-9-]*[a-z0-9]$" >nul
if errorlevel 1 (
    echo Error: Prefix must contain only lowercase letters, numbers, and hyphens
    echo        Must start and end with letter or number
    exit /b 1
)
if "!prefix:~20!" neq "" (
    echo Error: Prefix must be 20 characters or less
    exit /b 1
)
exit /b 0

:get_region_city
set "region=%~1"
if "%region%"=="eu-west-1" set "city=dublin" & exit /b
if "%region%"=="eu-west-2" set "city=london" & exit /b
if "%region%"=="eu-west-3" set "city=paris" & exit /b
if "%region%"=="eu-central-1" set "city=frankfurt" & exit /b
if "%region%"=="eu-central-2" set "city=zurich" & exit /b
if "%region%"=="eu-south-1" set "city=milan" & exit /b
if "%region%"=="eu-south-2" set "city=madrid" & exit /b
if "%region%"=="eu-north-1" set "city=stockholm" & exit /b
if "%region%"=="us-east-1" set "city=virginia" & exit /b
if "%region%"=="us-east-2" set "city=ohio" & exit /b
if "%region%"=="us-west-1" set "city=california" & exit /b
if "%region%"=="us-west-2" set "city=oregon" & exit /b
if "%region%"=="ap-east-1" set "city=hongkong" & exit /b
if "%region%"=="ap-south-1" set "city=mumbai" & exit /b
if "%region%"=="ap-south-2" set "city=hyderabad" & exit /b
if "%region%"=="ap-northeast-1" set "city=tokyo" & exit /b
if "%region%"=="ap-northeast-2" set "city=seoul" & exit /b
if "%region%"=="ap-northeast-3" set "city=osaka" & exit /b
if "%region%"=="ap-southeast-1" set "city=singapore" & exit /b
if "%region%"=="ap-southeast-2" set "city=sydney" & exit /b
if "%region%"=="ap-southeast-3" set "city=jakarta" & exit /b
if "%region%"=="ap-southeast-4" set "city=melbourne" & exit /b
set "city=unknown"
exit /b

REM Ask for and validate prefix
:get_prefix
set /p "PREFIX=Enter your prefix for AWS resources (random) [default: random]: "
if "!PREFIX!"=="" (
    call :generate_random_prefix
    set "PREFIX=!prefix!"
    echo Using random prefix: !PREFIX!
)
call :validate_prefix "!PREFIX!"
if errorlevel 1 goto get_prefix

echo Using prefix: !PREFIX!

REM Ask for AWS region
:get_region
set /p "AWS_REGION=Enter AWS region (default: eu-west-1): "
if "!AWS_REGION!"=="" set "AWS_REGION=eu-west-1"

call :get_region_city "!AWS_REGION!"
if "!city!"=="unknown" (
    echo Unsupported region. Please choose from:
    echo EMEA: eu-west-1/2/3, eu-central-1/2, eu-south-1/2, eu-north-1
    echo US: us-east-1/2, us-west-1/2
    echo APAC: ap-east-1, ap-south-1/2, ap-northeast-1/2/3, ap-southeast-1/2/3/4
    goto get_region
)

set "REGION_CITY=!city!"
echo Using AWS region: !AWS_REGION! (!REGION_CITY!)

REM Create backup directory with timestamp
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (
    set "datestamp=%%c%%a%%b"
)
for /f "tokens=1-2 delims=: " %%a in ('time /t') do (
    set "timestamp=%%a%%b"
)
set "BACKUP_DIR=backups_!datestamp!_!timestamp!"
mkdir "!BACKUP_DIR!" 2>nul

REM Function to update prefix in file using PowerShell (more reliable than batch for text processing)
:update_prefix
set "file=%~1"
if exist "!file!" (
    echo Updating !file!...
    powershell -Command ^
        "$content = Get-Content -Path '%~1'; ^
        $content = $content -replace '([a-z0-9-]*)-aws-cml', '%PREFIX%-aws-cml'; ^
        $content = $content -replace 'cml-[a-z]*-([a-z0-9-]*)', 'cml-%REGION_CITY%-%PREFIX%'; ^
        Set-Content -Path '%~1' -Value $content"
)
exit /b

REM Backup and update all relevant files
echo Creating backups in !BACKUP_DIR!...
for %%F in (
    "config.yml"
    "documentation\AWS.md"
    "modules\deploy\aws\main.tf"
    "modules\deploy\main.tf"
    "variables.tf"
) do (
    if exist "%%~F" (
        copy "%%~F" "!BACKUP_DIR!\%%~nxF.bak" >nul
        call :update_prefix "%%~F"
    )
)

echo Configuration updated with prefix: !PREFIX!
echo Backups created in: !BACKUP_DIR!\

REM Store the root directory
set "ROOT_DIR=%CD%"

cd modules\deploy

REM Check if backend configuration exists
if exist "config\backend.hcl" (
    echo Initializing backend...
    terraform init -migrate-state
)

cd "%ROOT_DIR%"

REM Ask for and validate prefix for Azure
:get_azure_prefix
set /p "AZURE_PREFIX=Enter your prefix for Azure resources (random) [default: random]: "
if "!AZURE_PREFIX!"=="" (
    call :generate_random_prefix
    set "AZURE_PREFIX=!prefix!"
    echo Using random prefix: !AZURE_PREFIX!
)
call :validate_prefix "!AZURE_PREFIX!"
if errorlevel 1 goto get_azure_prefix

echo Using prefix for Azure: !AZURE_PREFIX!

REM Ask for Azure region
:get_azure_region
set /p "AZURE_REGION=Enter Azure region (default: westus): "
if "!AZURE_REGION!"=="" set "AZURE_REGION=westus"

REM Create backup directory with timestamp for Azure
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (
    set "datestamp=%%c%%a%%b"
)
for /f "tokens=1-2 delims=: " %%a in ('time /t') do (
    set "timestamp=%%a%%b"
)
set "AZURE_BACKUP_DIR=backups_azure_!datestamp!_!timestamp!"
mkdir "!AZURE_BACKUP_DIR!" 2>nul

REM Function to update prefix in file using PowerShell (more reliable than batch for text processing) for Azure
:update_azure_prefix
set "file=%~1"
if exist "!file!" (
    echo Updating !file!...
    powershell -Command ^
        "$content = Get-Content -Path '%~1'; ^
        $content = $content -replace '([a-z0-9-]*)-azure-cml', '%AZURE_PREFIX%-azure-cml'; ^
        Set-Content -Path '%~1' -Value $content"
)
exit /b

REM Backup and update all relevant files for Azure
echo Creating backups in !AZURE_BACKUP_DIR!...
for %%F in (
    "modules\deploy\azure\main.tf"
) do (
    if exist "%%~F" (
        copy "%%~F" "!AZURE_BACKUP_DIR!\%%~nxF.bak" >nul
        call :update_azure_prefix "%%~F"
    )
)

echo Configuration updated with prefix for Azure: !AZURE_PREFIX!
echo Backups created in: !AZURE_BACKUP_DIR!\

REM Ask for and validate prefix for GCP
:get_gcp_prefix
set /p "GCP_PREFIX=Enter your prefix for GCP resources (random) [default: random]: "
if "!GCP_PREFIX!"=="" (
    call :generate_random_prefix
    set "GCP_PREFIX=!prefix!"
    echo Using random prefix: !GCP_PREFIX!
)
call :validate_prefix "!GCP_PREFIX!"
if errorlevel 1 goto get_gcp_prefix

echo Using prefix for GCP: !GCP_PREFIX!

REM Ask for GCP region
:get_gcp_region
set /p "GCP_REGION=Enter GCP region (default: us-central1): "
if "!GCP_REGION!"=="" set "GCP_REGION=us-central1"

REM Create backup directory with timestamp for GCP
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (
    set "datestamp=%%c%%a%%b"
)
for /f "tokens=1-2 delims=: " %%a in ('time /t') do (
    set "timestamp=%%a%%b"
)
set "GCP_BACKUP_DIR=backups_gcp_!datestamp!_!timestamp!"
mkdir "!GCP_BACKUP_DIR!" 2>nul

REM Function to update prefix in file using PowerShell (more reliable than batch for text processing) for GCP
:update_gcp_prefix
set "file=%~1"
if exist "!file!" (
    echo Updating !file!...
    powershell -Command ^
        "$content = Get-Content -Path '%~1'; ^
        $content = $content -replace '([a-z0-9-]*)-gcp-cml', '%GCP_PREFIX%-gcp-cml'; ^
        Set-Content -Path '%~1' -Value $content"
)
exit /b

REM Backup and update all relevant files for GCP
echo Creating backups in !GCP_BACKUP_DIR!...
for %%F in (
    "modules\deploy\gcp\main.tf"
) do (
    if exist "%%~F" (
        copy "%%~F" "!GCP_BACKUP_DIR!\%%~nxF.bak" >nul
        call :update_gcp_prefix "%%~F"
    )
)

echo Configuration updated with prefix for GCP: !GCP_PREFIX!
echo Backups created in: !GCP_BACKUP_DIR!\

endlocal
