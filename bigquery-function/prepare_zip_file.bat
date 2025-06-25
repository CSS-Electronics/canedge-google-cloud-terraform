@echo off
setlocal enabledelayedexpansion

REM Read version from versions.cfg
for /f "tokens=1,2 delims==" %%a in ('type versions.cfg ^| findstr "bigquery_map_tables"') do (
    set VERSION=%%b
)

echo Building BigQuery Map Tables Function v%VERSION%...

REM Create temp directory
if exist temp_zip rmdir /s /q temp_zip
mkdir temp_zip

REM Copy files to temp directory
copy /y main_bqmap.py temp_zip\main.py
copy /y requirements.txt temp_zip\requirements.txt

REM Create zip file
cd temp_zip
powershell -command "Compress-Archive -Path * -DestinationPath ..\bigquery-map-tables-v%VERSION%.zip -Force"
cd ..

REM Clean up
rmdir /s /q temp_zip

echo Created bigquery-map-tables-v%VERSION%.zip
echo Upload this file to your input bucket
