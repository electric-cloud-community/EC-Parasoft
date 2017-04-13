@echo off
if "%~1" == "" (
  goto :usage
)

set SPEC_FILE="%~1"
if NOT EXIST %SPEC_FILE% (
   set ERROR_MSG=%SPEC_FILE% does not exit!
   goto :error
)

set SCRIPT_DIR=%~f0/..
REM Shift to skip the spec file name 
REM before reading in the rest of the args
shift
set EC_TEST_ARGS=%1 %2 %3 %4 %5 %6 %7 %8
REM shift 2 to read the next two args
shift
shift
set EC_TEST_ARGS2=%7 %8

set UTIL_DIR=%SCRIPT_DIR%/utils
set GRADLE_USER_HOME=%SCRIPT_DIR%/build/.gradle
set CURRENT_DIR="%cd%"

"%UTIL_DIR%/gradlew" test -PspecFile=%SPEC_FILE% -PcurrentDir=%CURRENT_DIR% -PcmdLineArgs="%EC_TEST_ARGS% %EC_TEST_ARGS2%" -b "%UTIL_DIR%/build.gradle" --project-cache-dir "%GRADLE_USER_HOME%/.gradle-cache" 
goto :EOF

:error
echo Error: %ERROR_MSG%
goto :usage
goto :EOF

:usage
echo "Usage: ec-specs <specs file or directory> [--server <hostname>] [--port <port>] [--secure true|false|1|0] [--user <userName>] [--password <password>] [--testReportDir <test report directory>]"
goto :EOF



