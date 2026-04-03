param(
    [string]$AdapterRoot = "C:\Users\Damian\AppData\Local\npm-cache\_npx\43414d9b790239bb\node_modules\@paperclipai\adapter-codex-local"
)

$target = Join-Path $AdapterRoot "dist\server\codex-home.js"

if (-not (Test-Path -LiteralPath $target)) {
    throw "Adapter file not found: $target"
}

$raw = Get-Content -LiteralPath $target -Raw

if ($raw -match "copy fallback for Windows symlink restrictions") {
    Write-Host "Patch already present in $target"
    exit 0
}

$original = @"
async function ensureSymlink(target, source) {
    const existing = await fs.lstat(target).catch(() => null);
    if (!existing) {
        await ensureParentDir(target);
        await fs.symlink(source, target);
        return;
    }
    if (!existing.isSymbolicLink()) {
        return;
    }
    const linkedPath = await fs.readlink(target).catch(() => null);
    if (!linkedPath)
        return;
    const resolvedLinkedPath = path.resolve(path.dirname(target), linkedPath);
    if (resolvedLinkedPath === source)
        return;
    await fs.unlink(target);
    await fs.symlink(source, target);
}
"@

$replacement = @"
async function ensureSymlink(target, source) {
    const fallbackToCopy = async () => {
        // copy fallback for Windows symlink restrictions
        await ensureParentDir(target);
        await fs.copyFile(source, target);
    };
    const trySymlink = async () => {
        try {
            await fs.symlink(source, target);
        }
        catch (error) {
            if (error?.code === "EPERM" || error?.code === "EACCES" || error?.code === "UNKNOWN") {
                await fallbackToCopy();
                return;
            }
            throw error;
        }
    };
    const existing = await fs.lstat(target).catch(() => null);
    if (!existing) {
        await ensureParentDir(target);
        await trySymlink();
        return;
    }
    if (!existing.isSymbolicLink()) {
        return;
    }
    const linkedPath = await fs.readlink(target).catch(() => null);
    if (!linkedPath)
        return;
    const resolvedLinkedPath = path.resolve(path.dirname(target), linkedPath);
    if (resolvedLinkedPath === source)
        return;
    await fs.unlink(target);
    await trySymlink();
}
"@

if (-not $raw.Contains($original)) {
    throw "Expected ensureSymlink block not found in $target"
}

$backup = "$target.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item -LiteralPath $target -Destination $backup -Force

$patched = $raw.Replace($original, $replacement)
Set-Content -LiteralPath $target -Value $patched -NoNewline

Write-Host "Patched $target"
Write-Host "Backup: $backup"