@echo off
echo 🚀 Starting ZamaFundVault Frontend...
echo.

REM Change to frontend directory
cd /d "%~dp0"

REM Check if node_modules exists
if not exist "node_modules" (
    echo 📦 Installing dependencies...
    npm install
    echo.
)

REM Set port to 3017
set PORT=3017
set BROWSER=none
set DANGEROUSLY_DISABLE_HOST_CHECK=true
set SKIP_PREFLIGHT_CHECK=true

echo 🌐 Starting development server on http://localhost:3017
echo 🔒 SecretSwap DEX available at http://localhost:3017/secretswap.html
echo.
echo Press Ctrl+C to stop the server
echo.

REM Start the development server
npm start

pause