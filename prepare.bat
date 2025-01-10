@echo off
rem
rem This file is part of Cisco Modeling Labs
rem Copyright (c) 2019-2025, Cisco Systems, Inc.
rem All rights reserved.
rem

goto start

:ask_yes_no
set /p "answer=%~1 (yes/no): "
set "answer=%answer:~0,1%"
if /i "%answer%"=="y" (
    exit /b 1
) else if /i "%answer%"=="n" (
    exit /b 0
) else (
    echo Please answer yes or no.
    goto :ask_yes_no
)

:start
cd modules\deploy

call :ask_yes_no "Cloud - Enable AWS?"
if errorlevel 1 (
    echo Enabling AWS.
    copy aws-on.t-f aws.tf
) else (
    echo Disabling AWS.
    copy aws-off.t-f aws.tf
)

call :ask_yes_no "Cloud - Enable Azure?"
if errorlevel 1 (
    echo Enabling Azure.
    copy azure-on.t-f azure.tf
) else (
    echo Disabling Azure.
    copy azure-off.t-f azure.tf
)

cd ..\..
cd modules\secrets

call :ask_yes_no "External Secrets Manager - Enable Conjur?"
if errorlevel 1 (
    echo Enabling Conjur.
    copy conjur-on.t-f conjur.tf
) else (
    echo Disabling Conjur.
    copy conjur-off.t-f conjur.tf
)
call :ask_yes_no "External Secrets Manager - Enable Vault?"
if errorlevel 1 (
    echo Enabling Vault.
    copy vault-on.t-f vault.tf
) else (
    echo Disabling Vault.
    copy vault-off.t-f vault.tf
)
