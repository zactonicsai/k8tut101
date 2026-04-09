@echo off
REM ============================================================
REM  install-prereqs.bat
REM  Installs Docker Desktop, kind, and kubectl on Windows
REM  Uses winget (Windows 10 1809+ / Windows 11)
REM  Right-click -> "Run as administrator"
REM ============================================================

setlocal enabledelayedexpansion

echo.
echo ========================================
echo  Kubernetes Prerequisites Installer
echo  Windows Edition
echo ========================================
echo.

REM --- Check admin privileges ---
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] This script must be run as Administrator.
    echo         Right-click the file and choose "Run as administrator".
    echo.
    pause
    exit /b 1
)

REM --- Check for winget ---
where winget >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] winget is not installed.
    echo         winget comes with Windows 10 1809+ and Windows 11.
    echo         Install it from the Microsoft Store: "App Installer"
    echo         https://apps.microsoft.com/detail/9nblggh4nns1
    echo.
    pause
    exit /b 1
)

echo [INFO] winget detected. Starting installation...
echo.

REM ============================================================
REM  Step 1/3: Docker Desktop
REM ============================================================
echo ========================================
echo  Step 1/3: Docker Desktop
echo ========================================

where docker >nul 2>&1
if %errorLevel% equ 0 (
    echo [ OK ] Docker already installed
    docker --version
) else (
    echo [INFO] Installing Docker Desktop via winget...
    winget install -e --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
    if !errorLevel! neq 0 (
        echo [WARN] winget install failed. You can install manually from:
        echo        https://www.docker.com/products/docker-desktop/
    ) else (
        echo [ OK ] Docker Desktop installed
        echo [WARN] You MUST launch Docker Desktop manually before using kind.
        echo [WARN] A reboot may be required.
    )
)
echo.

REM ============================================================
REM  Step 2/3: kind (Kubernetes in Docker)
REM ============================================================
echo ========================================
echo  Step 2/3: kind
echo ========================================

where kind >nul 2>&1
if %errorLevel% equ 0 (
    echo [ OK ] kind already installed
    kind --version
) else (
    echo [INFO] Installing kind via winget...
    winget install -e --id Kubernetes.kind --accept-source-agreements --accept-package-agreements
    if !errorLevel! neq 0 (
        echo [WARN] winget failed. Falling back to manual download...
        echo [INFO] Downloading kind binary...

        REM Detect architecture
        set "KIND_ARCH=amd64"
        if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "KIND_ARCH=arm64"

        REM Create tools directory
        if not exist "%USERPROFILE%\k8s-tools" mkdir "%USERPROFILE%\k8s-tools"

        powershell -Command "Invoke-WebRequest -Uri 'https://kind.sigs.k8s.io/dl/v0.23.0/kind-windows-!KIND_ARCH!' -OutFile '%USERPROFILE%\k8s-tools\kind.exe'"
        if !errorLevel! equ 0 (
            echo [ OK ] kind.exe downloaded to %USERPROFILE%\k8s-tools\
            setx PATH "%PATH%;%USERPROFILE%\k8s-tools" >nul
            echo [INFO] Added %USERPROFILE%\k8s-tools to PATH (new terminals only)
        ) else (
            echo [ERR ] Failed to download kind
        )
    ) else (
        echo [ OK ] kind installed
    )
)
echo.

REM ============================================================
REM  Step 3/3: kubectl
REM ============================================================
echo ========================================
echo  Step 3/3: kubectl
echo ========================================

where kubectl >nul 2>&1
if %errorLevel% equ 0 (
    echo [ OK ] kubectl already installed
    kubectl version --client
) else (
    echo [INFO] Installing kubectl via winget...
    winget install -e --id Kubernetes.kubectl --accept-source-agreements --accept-package-agreements
    if !errorLevel! neq 0 (
        echo [WARN] winget failed. Falling back to manual download...

        if not exist "%USERPROFILE%\k8s-tools" mkdir "%USERPROFILE%\k8s-tools"

        echo [INFO] Fetching latest kubectl version...
        for /f %%i in ('powershell -Command "(Invoke-WebRequest -Uri https://dl.k8s.io/release/stable.txt -UseBasicParsing).Content.Trim()"') do set KVER=%%i

        echo [INFO] Downloading kubectl !KVER!...
        powershell -Command "Invoke-WebRequest -Uri 'https://dl.k8s.io/release/!KVER!/bin/windows/amd64/kubectl.exe' -OutFile '%USERPROFILE%\k8s-tools\kubectl.exe'"

        if !errorLevel! equ 0 (
            echo [ OK ] kubectl.exe downloaded to %USERPROFILE%\k8s-tools\
            setx PATH "%PATH%;%USERPROFILE%\k8s-tools" >nul
        ) else (
            echo [ERR ] Failed to download kubectl
        )
    ) else (
        echo [ OK ] kubectl installed
    )
)
echo.

REM ============================================================
REM  Verification
REM ============================================================
echo ========================================
echo  Verification
echo ========================================
echo.
echo Installed versions:
echo.

where docker >nul 2>&1
if %errorLevel% equ 0 (
    for /f "delims=" %%i in ('docker --version 2^>nul') do echo   [OK] %%i
) else (
    echo   [MISSING] docker
)

where kind >nul 2>&1
if %errorLevel% equ 0 (
    for /f "delims=" %%i in ('kind --version 2^>nul') do echo   [OK] %%i
) else (
    echo   [MISSING] kind  (may need to open a new terminal)
)

where kubectl >nul 2>&1
if %errorLevel% equ 0 (
    echo   [OK] kubectl installed
) else (
    echo   [MISSING] kubectl  (may need to open a new terminal)
)

echo.
echo ========================================
echo  All Done!
echo ========================================
echo.
echo Next steps:
echo   1. RESTART your terminal (or reboot) so PATH changes take effect
echo   2. Launch Docker Desktop manually and wait for it to fully start
echo   3. Create a cluster:   kind create cluster --name demo
echo   4. Verify:             kubectl get nodes
echo.
echo Docs: https://kind.sigs.k8s.io/docs/user/quick-start/
echo.
pause
endlocal
