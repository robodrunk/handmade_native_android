@Echo off

set ANDROID_STUDIO=C:\AndroidStudio
set SDK=C:\Android\Sdk
set BUILD_TOOLS_VERSION=35.0.0
set BUILD_TOOLS=%SDK%\build-tools\%BUILD_TOOLS_VERSION%
set PLATFORM=%SDK%\platforms\android-35
set OSPATH=windows-x86_64
set CLANG_VER=x86_64-linux-android35-clang++.cmd

set JAVA_HOME=C:\AndroidStudio\jbr

set CUR_DIR=%~dp0
set BUILD_DIR=%CUR_DIR%\__build
set PROJECT_DIR=%CUR_DIR%

set NDK_VERSION=27.0.12077973
set NDK=%SDK%\ndk\%NDK_VERSION%

set ARM_TOOLCHAIN=%NDK%\toolchains\llvm\prebuilt\%OSPATH%\bin\%CLANG_VER%

rem set SYSROOT=%NDK%\sources\android\support\include

rem # TOOLS
set MKDIR="C:\Program Files\Git\usr\bin\mkdir.exe"
set TOOL_JAVAC=%ANDROID_STUDIO%\jbr\bin\javac.exe
set TOOL_AAPT=%BUILD_TOOLS%\aapt.exe
set TOOL_ZIPALIGN=%BUILD_TOOLS%\zipalign.exe
set TOOL_D8=%BUILD_TOOLS%\d8.bat
set TOOL_APKSIGNER=%BUILD_TOOLS%\apksigner.bat

rem # Show variables
echo Current Dir: %CUR_DIR%

rem goto compile_classes
rem goto end

rem # Target Outputs
set DIR_ARM_V7A=%BUILD_DIR%\apk\lib\armeabi-v7a
set DIR_ARM64_V8A=%BUILD_DIR%\apk\lib\arm64-v8a

rem goto align_package
rem # rm -rf $BUILD_DIR

%MKDIR% -p %BUILD_DIR%\gen %BUILD_DIR%\obj %BUILD_DIR%\apk

%MKDIR% -p %BUILD_DIR%\apk\lib\armeabi-v7a
%MKDIR% -p %BUILD_DIR%\apk\lib\arm64-v8a 
rem %MKDIR% -p %BUILD_DIR%\apk\lib\x86
rem %MKDIR% -p %BUILD_DIR%\apk\lib\arm

rem goto end

rem #-------------------------------------------
rem #-------------------------------------------
rem #      JNI
rem #-------------------------------------------
rem #-------------------------------------------

set LOCAL_LDFLAGS=-ljnigraphics -llog -landroid
set DEFINES=-DHANDMADE_SLOW
set CFLAGS=-g -O0 -fPIC -shared -static-libstdc++

rem #set TARGET=%DIR_ARM_V7A%\libandroid_handmade.so 
set SOURCES=jni\android_handmade.cpp

rem if exist %TARGET% goto do_make_package

rem # Build .SO Module
echo ARM_TOOLCHAIN: %ARM_TOOLCHAIN%

rem set TARGET_ARCH_ABI=arm-v7a
rem set SYSROOT=--sysroot=%NDK%\platforms\android-21/arch-arm64  
set TARGET=--target=armv7a-linux-android27
call %ARM_TOOLCHAIN% %DEFINES% %CFLAGS% %TARGET% -o %DIR_ARM_V7A%\libandroid_handmade.so %SOURCES% %LOCAL_LDFLAGS%

rem set TARGET_ARCH_ABI=arm64-v8a
set TARGET=--target=aarch64-linux-android27
call %ARM_TOOLCHAIN% %DEFINES% %CFLAGS% %TARGET% -o %DIR_ARM64_V8A%\libandroid_handmade.so  %SOURCES% %LOCAL_LDFLAGS%

rem goto end

rem --------------------------------------------------------------------------------
rem --------------------------------------------------------------------------------
rem ----        Build APK                                                     ------
rem --------------------------------------------------------------------------------
rem --------------------------------------------------------------------------------

:do_make_package

rem if exist %BUILD_DIR%\apk\classes.jar goto re_package

%TOOL_AAPT% package -f -m -J %BUILD_DIR%\gen -S res -A assets -M AndroidManifest.xml -I %PLATFORM%\android.jar

%TOOL_JAVAC% -classpath "%PLATFORM%\android.jar" -d "%BUILD_DIR%\obj" ^
    "%BUILD_DIR%\gen\com\hereket\handmade_native_android\R.java" ^
    java\com\hereket\handmade_native_android\MainActivity.java

rem # javac -h __build \
rem #     -classpath "${PLATFORM}/android.jar:${BUILD_DIR}/obj" \
rem #     java/com/hereket/handmade_native_android/MainActivity.java


rem set CLASS_FILES=$(find $BUILD_DIR/obj/ -iname "*.class")
rem # for x in $CLASS_FILES; do echo $x; done;
rem call %TOOL_D8% %CLASS_FILES% ^
rem    --output $BUILD_DIR/apk/my_classes.jar ^
rem    --no-desugaring

rem $(find $BUILD_DIR/obj/ -iname "*.class")

:compile_classes

set CLASS_FILES=
for /r %BUILD_DIR%\obj\ %%i in (*.class) do (
  call :expand_class_files %%i
)
rem # for x in $CLASS_FILES; do echo $x; done;
echo %CLASS_FILES%

call %TOOL_D8% %CLASS_FILES% ^
   --output %BUILD_DIR%\apk\ ^
   --no-desugaring

rem goto end

goto re_package

:expand_class_files
set CLASS_FILES=%1 %CLASS_FILES%
goto end

rem #Not used in this cmd
pushd $BUILD_DIR/apk
rem # TODO: Merge d8 passes?
"${BUILD_TOOLS}/d8" classes.dex \
    ${PLATFORM}/android.jar \

popd

:re_package
%TOOL_AAPT% package -f -M AndroidManifest.xml -S res ^
    -A assets ^
    -I "%PLATFORM%\android.jar" ^
    -F %BUILD_DIR%\handmade_native_android.unsigned.apk %BUILD_DIR%\apk\

:align_package
call %TOOL_ZIPALIGN% -f -p 4 ^
    %BUILD_DIR%\handmade_native_android.unsigned.apk %BUILD_DIR%\handmade_native_android.aligned.apk

:sign_package
call %TOOL_APKSIGNER% sign --ks keystore.jks ^
    --ks-key-alias androidkey --ks-pass pass:android ^
    --key-pass pass:android --out %BUILD_DIR%\handmade_native_android.apk ^
    %BUILD_DIR%\handmade_native_android.aligned.apk

if "%1" NEQ "install" goto end

rem # ################################################################################
rem # ## RUN ON DEVICE
rem # ################################################################################

"%SDK%\platform-tools\adb" install -r %BUILD_DIR%\handmade_native_android.apk

"%SDK%\platform-tools\adb" shell am start -n com.hereket.handmade_native_android/.MainActivity

:end
