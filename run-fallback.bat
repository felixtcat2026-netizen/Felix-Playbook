@echo off
setlocal

set OLLAMA_EXE=C:\Users\Damian\AppData\Local\Programs\Ollama\ollama.exe

if not exist "%OLLAMA_EXE%" (
  echo ERROR: ollama.exe not found at "%OLLAMA_EXE%"
  exit /b 1
)

echo Trying cloud model first...
"%OLLAMA_EXE%" run qwen3.5:397b-cloud
if %ERRORLEVEL% EQU 0 exit /b 0

echo Cloud model failed. Falling back to gemma3:1b...
"%OLLAMA_EXE%" run gemma3:1b
if %ERRORLEVEL% EQU 0 exit /b 0

echo gemma3:1b failed. Falling back to llama3.2:1b...
"%OLLAMA_EXE%" run llama3.2:1b
exit /b %ERRORLEVEL%

endlocal