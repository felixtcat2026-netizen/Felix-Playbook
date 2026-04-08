@echo off
setlocal

set OLLAMA_EXE=C:\Users\Damian\AppData\Local\Programs\Ollama\ollama.exe

if not exist "%OLLAMA_EXE%" (
  echo ERROR: ollama.exe not found at "%OLLAMA_EXE%"
  exit /b 1
)

"%OLLAMA_EXE%" run qwen3.5:4b

endlocal