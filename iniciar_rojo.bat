@echo off
title Rojo Server - Inventory & Equipment Suite
echo ========================================================
echo   Iniciando Rojo Server para Roblox Inventory Suite...
echo ========================================================

set ROJO_EXE=..\rojo.exe
if not exist "%ROJO_EXE%" (
    set ROJO_EXE=rojo.exe
)

echo Usando ejecutable: %ROJO_EXE%
echo Escuchando en puerto 34873...
echo Abre Roblox Studio, Baseplate vacio y pulsa Connect en el plugin de Rojo.
echo.

"%ROJO_EXE%" serve default.project.json --port 34873
pause
