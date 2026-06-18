param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Resolve-Path (Join-Path $PSScriptRoot "..")

$expectedModules = @("app", "core", "features", "networking", "storage", "data", "presentation", "runtime", "ui")

$androidPluginIds = @{
    "app" = "com.android.application"
    "core" = "com.android.library"
    "features" = "com.android.library"
    "networking" = "com.android.library"
    "storage" = "com.android.library"
    "data" = "com.android.library"
    "presentation" = "com.android.library"
    "runtime" = "com.android.library"
    "ui" = "com.android.library"
}

$moduleNamespaces = @{
    "app" = "dev.example.moodlenative"
    "core" = "dev.example.moodlenative.core"
    "features" = "dev.example.moodlenative.features"
    "networking" = "dev.example.moodlenative.networking"
    "storage" = "dev.example.moodlenative.storage"
    "data" = "dev.example.moodlenative.data"
    "presentation" = "dev.example.moodlenative.presentation"
    "runtime" = "dev.example.moodlenative.runtime"
    "ui" = "dev.example.moodlenative.ui"
}

$projectDependencies = @{
    "app" = @("core", "runtime", "storage", "ui")
    "core" = @()
    "features" = @("core")
    "networking" = @()
    "storage" = @("core")
    "data" = @("core", "features", "networking", "storage")
    "presentation" = @("core", "features")
    "runtime" = @("core", "data", "features", "presentation", "storage")
    "ui" = @("core", "features", "presentation")
}

$sourceImports = @{
    "app" = @("core", "runtime", "storage", "ui")
    "core" = @()
    "features" = @("core")
    "networking" = @()
    "storage" = @("core")
    "data" = @("core", "features", "networking", "storage")
    "presentation" = @("core", "features")
    "runtime" = @("core", "data", "features", "presentation", "storage")
    "ui" = @("core", "features", "presentation")
}

$allowedAppRootSourceFiles = @(
    "MainActivity.kt"
)

$allowedAppUiImportSegments = @("core", "features", "presentation")
$allowedAppPresentationImportSegments = @("core", "features")

$knownPackageSegments = @("core", "data", "features", "networking", "storage", "presentation", "runtime", "ui")
$errors = New-Object System.Collections.Generic.List[string]

function Test-DataNetworkingImportAllowed {
    param(
        [string]$FileName,
        [string]$Line,
        [string]$SourceSet
    )

    if ($SourceSet -eq "test") {
        return $FileName -like "*NetworkMappingTest.kt"
    }

    if ($FileName -like "*NetworkMapping.kt" -or
        $FileName -eq "LmsWebServiceSessionMapping.kt" -or
        $FileName -like "*WebServiceGateway.kt") {
        return $true
    }

    return $false
}

function Test-IsAppUiSourceFile {
    param([string]$File)

    $appUiSourceRoot = Join-Path $root "app\src\main\kotlin\dev\example\moodlenative\ui"
    if (-not (Test-Path $appUiSourceRoot)) {
        return $false
    }

    $uiRootPath = (Resolve-Path $appUiSourceRoot).Path
    return $File.StartsWith(
        "$uiRootPath$([System.IO.Path]::DirectorySeparatorChar)",
        [System.StringComparison]::OrdinalIgnoreCase
    )
}

function Test-IsAppPresentationSourceFile {
    param([string]$File)

    $appPresentationSourceRoot = Join-Path $root "app\src\main\kotlin\dev\example\moodlenative\presentation"
    if (-not (Test-Path $appPresentationSourceRoot)) {
        return $false
    }

    $presentationRootPath = (Resolve-Path $appPresentationSourceRoot).Path
    return $File.StartsWith(
        "$presentationRootPath$([System.IO.Path]::DirectorySeparatorChar)",
        [System.StringComparison]::OrdinalIgnoreCase
    )
}

$appRootSource = Join-Path $root "app\src\main\kotlin\dev\example\moodlenative"
if (Test-Path $appRootSource) {
    Get-ChildItem -Path $appRootSource -File -Filter "*.kt" | ForEach-Object {
        if ($_.Name -notin $allowedAppRootSourceFiles) {
            $relativePath = Resolve-Path -Path $_.FullName -Relative
            $errors.Add(":app root package must stay limited to entry files, found $relativePath")
        }
    }
}

$settingsFile = Join-Path $root "settings.gradle.kts"
if (-not (Test-Path $settingsFile)) {
    $errors.Add("Missing settings.gradle.kts")
} else {
    $settingsContent = Get-Content -Path $settingsFile -Raw
    $includedModules = [regex]::Matches($settingsContent, '":([^"]+)"') |
        ForEach-Object { $_.Groups[1].Value } |
        Sort-Object -Unique
    $expectedIncludedModules = $expectedModules | Sort-Object

    $unexpectedIncludes = @($includedModules | Where-Object { $_ -notin $expectedIncludedModules })
    foreach ($module in $unexpectedIncludes) {
        $errors.Add("settings.gradle.kts includes unexpected module :$module")
    }

    $missingIncludes = @($expectedIncludedModules | Where-Object { $_ -notin $includedModules })
    foreach ($module in $missingIncludes) {
        $errors.Add("settings.gradle.kts must include :$module")
    }
}

foreach ($module in $expectedModules) {
    $buildFile = Join-Path $root "$module\build.gradle.kts"
    if (-not (Test-Path $buildFile)) {
        $errors.Add("Missing build.gradle.kts for module :$module")
        continue
    }

    $content = Get-Content -Path $buildFile -Raw
    $expectedPluginId = $androidPluginIds[$module]
    if ($content -notmatch ('id\("' + [regex]::Escape($expectedPluginId) + '"\)')) {
        $errors.Add(":$module must use Gradle plugin '$expectedPluginId'")
    }

    $expectedNamespace = $moduleNamespaces[$module]
    if ($content -notmatch ('namespace\s*=\s*"' + [regex]::Escape($expectedNamespace) + '"')) {
        $errors.Add(":$module must use namespace '$expectedNamespace'")
    }

    if ($module -eq "app" -and $content -notmatch 'applicationId\s*=\s*"dev\.example\.moodlenative"') {
        $errors.Add(":app must use applicationId 'dev.example.moodlenative'")
    }

    $declaredDependencies = [regex]::Matches($content, '(?:api|implementation)\(project\(":([^"]+)"\)\)') |
        ForEach-Object { $_.Groups[1].Value } |
        Sort-Object -Unique
    $allowedDependencies = $projectDependencies[$module] | Sort-Object

    $unexpectedDependencies = @($declaredDependencies | Where-Object { $_ -notin $allowedDependencies })
    foreach ($dependency in $unexpectedDependencies) {
        $errors.Add(":$module must not depend on :$dependency")
    }

    $missingDependencies = @($allowedDependencies | Where-Object { $_ -notin $declaredDependencies })
    foreach ($dependency in $missingDependencies) {
        $errors.Add(":$module is expected to depend on :$dependency")
    }
}

foreach ($module in $sourceImports.Keys) {
    $sourceSets = @(
        @{ Name = "main"; Path = "$module\src\main\kotlin"; Required = $true },
        @{ Name = "test"; Path = "$module\src\test\kotlin"; Required = $false }
    )

    foreach ($sourceSet in $sourceSets) {
        $sourceRoot = Join-Path $root $sourceSet.Path
        if (-not (Test-Path $sourceRoot)) {
            if ($sourceSet.Required) {
                $errors.Add("Missing Kotlin source root for module :$module")
            }
            continue
        }

        $allowedImports = $sourceImports[$module]
        Get-ChildItem -Path $sourceRoot -Recurse -Filter "*.kt" | ForEach-Object {
            $file = $_.FullName
            $fileName = $_.Name
            $relativePath = Resolve-Path -Path $file -Relative
            foreach ($line in Get-Content -Path $file) {
                if ($module -eq "data" -and $sourceSet.Name -eq "main") {
                    if ([regex]::IsMatch($line, '^\s*class\s+MoodleNative[A-Za-z0-9_]*Repository\s*\(')) {
                        $errors.Add(":data repository primary constructor must be internal in $relativePath")
                    }

                    if ([regex]::IsMatch($line, '^\s*interface\s+[A-Za-z0-9_]*Gateway\b')) {
                        $errors.Add(":data gateway interface must be internal in $relativePath")
                    }

                    if ([regex]::IsMatch($line, '^\s*class\s+Lms[A-Za-z0-9_]*WebServiceGateway\b')) {
                        $errors.Add(":data web service gateway must be internal in $relativePath")
                    }

                    if ([regex]::IsMatch($line, '^\s*data\s+class\s+(?:LmsNotificationSnapshot|LmsUserPreference|LmsUserPreferenceUpdate|LmsSiteInfo|CourseFavoriteUpdate)\b')) {
                        $errors.Add(":data gateway helper model must be internal in $relativePath")
                    }
                }

                $match = [regex]::Match($line, '^\s*import\s+dev\.example\.moodlenative\.([A-Za-z0-9_]+)(?:\.|$)')
                if (-not $match.Success) {
                    continue
                }

                $segment = $match.Groups[1].Value
                if ($module -eq "app" -and $sourceSet.Name -eq "main") {
                    if ($fileName -eq "MoodleNativeApp.kt" -and $segment -in @("data", "runtime", "storage")) {
                        $errors.Add(":app MoodleNativeApp.kt must receive presentation state instead of importing $segment, found '$line' in $relativePath")
                    }

                    if ((Test-IsAppUiSourceFile -File $file) -and
                        $segment -notin $allowedAppUiImportSegments) {
                        $errors.Add(":app ui package may only import core, features, or presentation from dev.example.moodlenative, found '$line' in $relativePath")
                    }

                    if ((Test-IsAppPresentationSourceFile -File $file) -and
                        $segment -notin $allowedAppPresentationImportSegments) {
                        $errors.Add(":app presentation package may only import core or features from dev.example.moodlenative, found '$line' in $relativePath")
                    }
                }

                if ($segment -in $knownPackageSegments) {
                    if ($segment -ne $module -and $segment -notin $allowedImports) {
                        $errors.Add(":$module has forbidden import '$line' in $relativePath")
                    }

                    if ($module -eq "data" -and $segment -eq "networking" -and
                        -not (Test-DataNetworkingImportAllowed -FileName $fileName -Line $line -SourceSet $sourceSet.Name)) {
                        $errors.Add(":data must keep networking import in mapping or adapter code, found '$line' in $relativePath")
                    }
                } elseif ($module -ne "app") {
                    $errors.Add(":$module must not import app package '$line' in $relativePath")
                }
            }
        }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Android architecture checks passed."
