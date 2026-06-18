param(
    [Parameter(Position = 0)]
    [ValidateSet("doctor", "check-architecture", "test-core", "test-features", "test-networking", "test-presentation", "test-runtime", "test-storage", "test-data", "test-ui", "build-app", "check")]
    [string]$Command = "doctor"
)

$ErrorActionPreference = "Stop"

$sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$studioJbr = "C:\Program Files\Android\Android Studio\jbr"
$gradlew = Join-Path $PSScriptRoot "..\gradlew.bat"
$architectureCheck = Join-Path $PSScriptRoot "check-architecture.ps1"

$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk
$env:JAVA_HOME = $studioJbr
$env:Path = "$studioJbr\bin;$sdk\platform-tools;$sdk\emulator;$env:Path"

function Assert-Path([string]$Path, [string]$Name) {
    if (-not (Test-Path $Path)) {
        throw "$Name not found: $Path"
    }
}

Assert-Path $sdk "Android SDK"
Assert-Path $studioJbr "Android Studio JBR"

switch ($Command) {
    "doctor" {
        Write-Host "ANDROID_HOME=$env:ANDROID_HOME"
        Write-Host "JAVA_HOME=$env:JAVA_HOME"
        & "$studioJbr\bin\java.exe" -version
    }
    "check-architecture" {
        Assert-Path $architectureCheck "Architecture check"
        & $architectureCheck
    }
    "test-core" {
        Assert-Path $gradlew "Gradle wrapper"
        & $gradlew ":core:testDebugUnitTest"
    }
    "test-features" {
        Assert-Path $gradlew "Gradle wrapper"
        & $gradlew ":features:testDebugUnitTest"
    }
    "test-networking" {
        Assert-Path $gradlew "Gradle wrapper"
        & $gradlew ":networking:testDebugUnitTest"
    }
    "test-presentation" {
        Assert-Path $gradlew "Gradle wrapper"
        & $gradlew ":presentation:testDebugUnitTest"
    }
    "test-runtime" {
        Assert-Path $gradlew "Gradle wrapper"
        & $gradlew ":runtime:testDebugUnitTest"
    }
    "test-storage" {
        Assert-Path $gradlew "Gradle wrapper"
        & $gradlew ":storage:testDebugUnitTest"
    }
    "test-data" {
        Assert-Path $gradlew "Gradle wrapper"
        & $gradlew ":data:testDebugUnitTest"
    }
    "test-ui" {
        Assert-Path $gradlew "Gradle wrapper"
        & $gradlew ":ui:testDebugUnitTest"
    }
    "build-app" {
        Assert-Path $gradlew "Gradle wrapper"
        & $gradlew ":app:assembleDebug"
    }
    "check" {
        Assert-Path $gradlew "Gradle wrapper"
        Assert-Path $architectureCheck "Architecture check"
        & $architectureCheck
        & $gradlew ":core:testDebugUnitTest" ":features:testDebugUnitTest" ":networking:testDebugUnitTest" ":presentation:testDebugUnitTest" ":runtime:testDebugUnitTest" ":storage:testDebugUnitTest" ":data:testDebugUnitTest" ":ui:testDebugUnitTest" ":app:assembleDebug"
    }
}
