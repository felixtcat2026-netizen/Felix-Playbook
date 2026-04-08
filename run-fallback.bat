@echo off
setlocal

set OLLAMA_EXE=C:\Users\Damian\AppData\Local\Programs\Ollama\ollama.exe

if not exist "%OLLAMA_EXE%" (
  echo ERROR: ollama.exe not found at "%OLLAMA_EXE%"
  exit /b 1
)

echo Trying qwen3.5:397b-cloud...
"%OLLAMA_EXE%" run qwen3.5:397b-cloud
if %ERRORLEVEL% EQU 0 exit /b 0

echo Cloud failed. Falling back to qwen3.5:4b...
"%OLLAMA_EXE%" run qwen3.5:4b
if %ERRORLEVEL% EQU 0 exit /b 0

echo qwen3.5:4b failed. Falling back to qwen3.5:2b...
"%OLLAMA_EXE%" run qwen3.5:2b
exit /b %ERRORLEVEL%

endlocal