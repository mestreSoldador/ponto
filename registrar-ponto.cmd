@echo off
rem Chamado pelo Agendador de Tarefas do Windows. Grava tudo em logs\ponto.log
cd /d "%~dp0"
if not exist logs mkdir logs
call "%~dp0node_modules\.bin\tsx.cmd" "%~dp0index.ts" %* >> "%~dp0logs\ponto.log" 2>&1
