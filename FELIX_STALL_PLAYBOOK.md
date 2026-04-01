# Felix Stall Playbook

Use this when Felix seems stalled, keeps replying with status only, or you are not sure whether real work is happening.

## 1. Check OpenClaw health

Run in PowerShell:

```powershell
& 'C:\Users\Damian\AppData\Roaming\npm\openclaw.cmd' gateway status
& 'C:\Users\Damian\AppData\Roaming\npm\openclaw.cmd' status --deep
```

Healthy signs:

- `Runtime: running`
- `RPC probe: ok`
- `Telegram OK`

If unhealthy, restart:

```powershell
& 'C:\Users\Damian\AppData\Roaming\npm\openclaw.cmd' gateway restart
```

## 2. Check whether Telegram is still being picked up

```powershell
Get-ChildItem 'C:\Users\Damian\.openclaw\telegram' -Recurse -Force |
Sort-Object LastWriteTime -Descending |
Select-Object -First 5 FullName, LastWriteTime, Length
```

Most important file:

- `C:\Users\Damian\.openclaw\telegram\update-offset-default.json`

Healthy sign:

- very recent `LastWriteTime`

If stale, Felix may not be seeing new Telegram messages yet.

## 3. Identify the active session file

```powershell
Get-ChildItem 'C:\Users\Damian\.openclaw\agents\main\sessions' -Force |
Sort-Object LastWriteTime -Descending |
Select-Object -First 10 Name, LastWriteTime, Length
```

Healthy sign:

- one session file updates right after you message Felix

Warning sign:

- only an old known-bad topic/session is updating

## 4. Inspect the live session tail

Replace `SESSION_FILE_HERE` with the file from step 3.

```powershell
Get-Content "C:\Users\Damian\.openclaw\agents\main\sessions\SESSION_FILE_HERE" -Tail 80
```

How to read it:

- only `message` entries = Felix is talking
- execution/tool entries = Felix is actually working

## 5. Search for execution signals

```powershell
Select-String -Path "C:\Users\Damian\.openclaw\agents\main\sessions\SESSION_FILE_HERE" -Pattern 'exec|tool|sessions_spawn|apply_patch|Get-Item|Resolve-Path|shell' |
Select-Object -Last 40 LineNumber, Line
```

Healthy sign:

- fresh matches after your latest command

Warning sign:

- no fresh execution lines after your request

## 6. Check whether target files are really changing

For `digital-product-studio` work:

```powershell
Get-ChildItem 'C:\Users\Damian\.openclaw\workspace\projects\digital-product-studio\deliverables' -Recurse -File |
Sort-Object LastWriteTime -Descending |
Select-Object -First 20 FullName, LastWriteTime, Length
```

Healthy sign:

- expected target files show a recent `LastWriteTime`

Warning sign:

- no file movement at all

## 7. Check managed task state

Run from the Felix Playbook repo:

```powershell
.\automation\agent-runtime\scripts\Get-AgentTasks.ps1
```

Use this when a task should be running in the managed task system.

## 8. Check tmux-backed tasks

```powershell
wsl sh -lc "tmux ls"
```

If you know the session name:

```powershell
wsl sh -lc "tmux capture-pane -p -t SESSION_NAME -S -200"
```

Healthy sign:

- real output in the pane, not just an idle prompt

## 9. Interpret the failure mode

Use this rule:

- gateway unhealthy -> restart OpenClaw
- Telegram stale -> wait 30-60 seconds after restart, then resend once
- old poisoned topic/session -> move to a fresh topic
- session active but no exec/tool lines -> Felix is talking, not working
- exec/tool lines exist but files do not change -> execution is failing
- files are changing -> let him continue

## 10. Recovery move: use a fresh topic with a smaller command

Use this exact pattern:

```text
This is a fresh execution session. Do not rely on prior thread memory.

Create exactly one file now:
FULL_PATH_HERE

Do not reply until Get-Item succeeds on that exact path.

Your reply must contain only:
1. SUCCESS or FAIL
2. exact absolute file path
3. exact Get-Item output if successful, or exact error if failed
4. codex_run_verified: true/false
5. local_apply_verified: true/false
```

## 11. Trust order

Trust signals in this order:

1. real file on disk
2. raw `Get-Item` or `Resolve-Path`
3. session log showing exec/tool calls
4. Telegram summary text

## 12. Practical rule of thumb

If Felix seems stuck:

1. verify gateway
2. verify Telegram pickup
3. inspect the session file
4. inspect file timestamps
5. switch to a fresh topic before escalating
