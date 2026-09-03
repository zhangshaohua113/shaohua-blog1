@echo off
chcp 936 >nul
title 一键双推 - GitHub 备份 + Pages 发布
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0一键双推.ps1"
if errorlevel 1 (echo [失败] 见上方错误信息) else (echo [完成] 备份与 Pages 均已推送)
pause