param(
    [string]$UtilsFile = "C:\Users\Damian\AppData\Local\npm-cache\_npx\43414d9b790239bb\node_modules\@paperclipai\adapter-utils\dist\server-utils.js"
)

if (-not (Test-Path -LiteralPath $UtilsFile)) {
    throw "Adapter utils file not found: $UtilsFile"
}

$raw = Get-Content -LiteralPath $UtilsFile -Raw

if ($raw -match "copy fallback for Windows skill injection restrictions") {
    Write-Host "Patch already present in $UtilsFile"
    exit 0
}

$original = @"
export async function ensurePaperclipSkillSymlink(source, target, linkSkill = (linkSource, linkTarget) => fs.symlink(linkSource, linkTarget)) {
    const existing = await fs.lstat(target).catch(() => null);
    if (!existing) {
        await linkSkill(source, target);
        return "created";
    }
    if (!existing.isSymbolicLink()) {
        return "skipped";
    }
    const linkedPath = await fs.readlink(target).catch(() => null);
    if (!linkedPath)
        return "skipped";
    const resolvedLinkedPath = path.resolve(path.dirname(target), linkedPath);
    if (resolvedLinkedPath === source) {
        return "skipped";
    }
    const linkedPathExists = await fs.stat(resolvedLinkedPath).then(() => true).catch(() => false);
    if (linkedPathExists) {
        return "skipped";
    }
    await fs.unlink(target);
    await linkSkill(source, target);
    return "repaired";
}
"@

$replacement = @"
export async function ensurePaperclipSkillSymlink(source, target, linkSkill = (linkSource, linkTarget) => fs.symlink(linkSource, linkTarget)) {
    const copyFallback = async () => {
        // copy fallback for Windows skill injection restrictions
        const sourceStats = await fs.stat(source);
        if (sourceStats.isDirectory()) {
            await fs.cp(source, target, { recursive: true });
            return;
        }
        await fs.copyFile(source, target);
    };
    const tryLink = async () => {
        try {
            await linkSkill(source, target);
        }
        catch (error) {
            if (error?.code === "EPERM" || error?.code === "EACCES" || error?.code === "UNKNOWN") {
                await copyFallback();
                return;
            }
            throw error;
        }
    };
    const existing = await fs.lstat(target).catch(() => null);
    if (!existing) {
        await tryLink();
        return "created";
    }
    if (!existing.isSymbolicLink()) {
        return "skipped";
    }
    const linkedPath = await fs.readlink(target).catch(() => null);
    if (!linkedPath)
        return "skipped";
    const resolvedLinkedPath = path.resolve(path.dirname(target), linkedPath);
    if (resolvedLinkedPath === source) {
        return "skipped";
    }
    const linkedPathExists = await fs.stat(resolvedLinkedPath).then(() => true).catch(() => false);
    if (linkedPathExists) {
        return "skipped";
    }
    await fs.unlink(target);
    await tryLink();
    return "repaired";
}
"@

if (-not $raw.Contains($original)) {
    throw "Expected ensurePaperclipSkillSymlink block not found in $UtilsFile"
}

$backup = "$UtilsFile.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item -LiteralPath $UtilsFile -Destination $backup -Force

$patched = $raw.Replace($original, $replacement)
Set-Content -LiteralPath $UtilsFile -Value $patched -NoNewline

Write-Host "Patched $UtilsFile"
Write-Host "Backup: $backup"