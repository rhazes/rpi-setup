@echo off
setlocal enabledelayedexpansion

:: ==============================
:: CONFIG
:: ==============================
set SSID=PiClassNet
set KEY=Raspberry123
set VERBOSE=1

:: ==============================
:: FUNCTION: LOGGING
:: ==============================
:log
if "%VERBOSE%"=="1" echo [INFO] %1
goto :eof

:error
echo [ERROR] %1
goto :eof

:: ==============================
:: CHECK ADMIN
:: ==============================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo This script MUST be run as Administrator.
    echo Right click the file and choose "Run as administrator".
    pause
    exit /b
)
call :log "Running with Administrator privileges"

:: ==============================
:: STEP 1 – SET UP MOBILE HOTSPOT
:: ==============================
call :log "Configuring mobile hotspot..."
netsh wlan set hostednetwork mode=allow ssid=%SSID% key=%KEY% >nul
if %errorlevel% neq 0 call :error "Failed to configure hosted network"

call :log "Starting mobile hotspot..."
netsh wlan start hostednetwork >nul
if %errorlevel% neq 0 call :error "Failed to start hosted network"

:: ==============================
:: STEP 2 – FIND ADAPTER NAMES
:: ==============================
call :log "Detecting network adapters..."

for /f "tokens=2 delims=:" %%a in ('netsh interface show interface ^| find "Connected"') do (
    set "adapter=%%a"
    set "adapter=!adapter:~1!"
    call :log "Connected adapter found: !adapter!"
)

:: Usually Ethernet is called "Ethernet"
set ETHERNET=Ethernet
set WIFI=Wi-Fi

call :log "Assuming Wi-Fi adapter is: %WIFI%"
call :log "Assuming Ethernet adapter is: %ETHERNET%"

:: ==============================
:: STEP 3 – ENABLE INTERNET SHARING (ICS)
:: ==============================
call :log "Enabling Internet Connection Sharing..."

powershell -Command ^
" $wifi = Get-NetAdapter -Name '%WIFI%'; ^
  $eth = Get-NetAdapter -Name '%ETHERNET%'; ^
  $share = New-Object -ComObject HNetCfg.HNetShare; ^
  $conns = $share.EnumEveryConnection; ^
  foreach ($c in $conns) { ^
    $p = $share.NetConnectionProps($c); ^
    if ($p.Name -eq '%WIFI%') { ^
        $cfg = $share.INetSharingConfigurationForINetConnection($c); ^
        $cfg.EnableSharing(0); ^
    } ^
    if ($p.Name -eq '%ETHERNET%') { ^
        $cfg2 = $share.INetSharingConfigurationForINetConnection($c); ^
        $cfg2.EnableSharing(1); ^
    } ^
  }"

if %errorlevel% neq 0 call :error "ICS setup may have failed"

:: ==============================
:: STEP 4 – SET STATIC IP ON ETHERNET (OPTIONAL BUT HELPFUL)
:: ==============================
call :log "Setting static IP on Ethernet adapter..."

netsh interface ip set address name="%ETHERNET%" static 192.168.137.1 255.255.255.0 >nul
if %errorlevel% neq 0 call :error "Could not set static IP"

:: ==============================
:: DONE
:: ==============================
echo.
echo =====================================
echo   Raspberry Pi Network Ready
echo   Hotspot Name: %SSID%
echo   Password: %KEY%
echo =====================================
echo.
echo Plug Pi into Ethernet and connect it to Wi-Fi "%SSID%"
echo Students can now use Raspberry Pi Connect.
pause
