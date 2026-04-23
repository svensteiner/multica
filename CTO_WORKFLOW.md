# CTO Agent — Multica Dev Pool Workflow

Dieses Dokument beschreibt den vollständigen Workflow, um Coding-Tasks vom CTO-Agenten
über Multica an den lokalen Claude-Daemon zu delegieren.

---

## System-Übersicht

```
CTO-Agent (Python)
    │
    ▼ multica CLI / REST API
Multica Backend (https://api.multica.ai)
    │
    ▼ WebSocket-Polling (alle ~3 Sek.)
Multica Daemon (WSL, PID ~1345, uptime 24h+)
    │
    ▼ spawnt subprocess
Claude Code CLI  →  arbeitet in Workspace-Dir
    │
    ▼
Code-Änderungen + Commits
```

### Beteiligte Komponenten

| Komponente | ID / Wert | Status |
|---|---|---|
| Workspace | `7dc3f131-842b-4fa5-ad59-15b7b309064c` | aktiv |
| Runtime (Claude, NucBoxM5Ultra) | `ea1c94d5-3820-45c5-80da-89012d337ea5` | online |
| CTO Agent | `b90d7546-83a4-4a89-9f99-b6a272967fcd` | idle |
| Auth-User | `mag.sven.steiner@gmail.com` | authentifiziert |

---

## Voraussetzungen prüfen

```bash
# 1. Auth-Status
wsl multica auth status
# Erwartet: User = Sven Steiner, Token vorhanden

# 2. Daemon läuft
wsl multica daemon status
# Erwartet: Daemon: running, Agents: claude, codex

# 3. Runtime online
wsl multica runtime list
# Erwartet: Claude (NucBoxM5Ultra) — status: online

# 4. CTO-Agent vorhanden
wsl multica agent list
# Erwartet: CTO — status: idle, runtime: ea1c94d5-...
```

---

## Schritt 1: Neues Coding-Issue anlegen

```bash
wsl multica issue create \
  --title "Fix TypeScript type errors in apps/web" \
  --description "Führe 'pnpm typecheck' aus. Behebbe alle TypeScript-Fehler in apps/web/. Committe die Fixes atomar im Format 'fix(web): ...'." \
  --priority high \
  --assignee CTO
```

Flags im Detail:
- `--title` — Kurzer Aufgabentitel (erscheint in der UI und im Daemon-Log)
- `--description` — Detaillierte Anforderungen (Markdown, mehrzeilig mit `$'...'` möglich)
- `--priority` — `low` | `medium` | `high` | `urgent`
- `--assignee CTO` — Weist direkt dem CTO-Agenten zu (Daemon sieht es sofort)

Alternativ: erst erstellen, dann zuweisen:

```bash
# Issue erstellen (gibt JSON mit id zurück)
wsl multica issue create \
  --title "Fix TypeScript type errors in apps/web" \
  --description "..." \
  --priority high

# Separat zuweisen (ISSUE_ID aus JSON-Output oben)
wsl multica issue assign <ISSUE_ID> --to CTO
```

### Beispiel-Issue: TypeScript-Fehler fixen

```bash
wsl multica issue create \
  --title "Fix TypeScript type errors in apps/web" \
  --description $'Führe folgende Schritte aus:\n\n1. cd /path/to/dev-pool\n2. pnpm typecheck 2>&1 | tee /tmp/typecheck.log\n3. Analysiere alle Fehler\n4. Behebe die Fehler (ohne Logik zu ändern, nur Typen korrigieren)\n5. Führe erneut pnpm typecheck aus — muss 0 Fehler ergeben\n6. Committe: fix(web): resolve TypeScript type errors\n\nRegeln:\n- Keine any-Typen einführen\n- Keine @ts-ignore-Kommentare\n- Nur Typfehler beheben, keine Logik-Änderungen' \
  --priority high \
  --assignee CTO
```

---

## Schritt 2: Daemon erkennt das Issue

Der Daemon pollt alle ~3 Sekunden (konfigurierbar via `MULTICA_DAEMON_POLL_INTERVAL`).

**Was passiert intern:**
1. Daemon fragt Backend: "Gibt es neue Tasks für meine Runtimes?"
2. Backend liefert das Issue zurück (da CTO-Agent an Runtime `ea1c94d5-...` gebunden)
3. Daemon loggt: `task received`, `picked task`
4. Daemon erstellt temporäres Workspace-Verzeichnis unter:
   `/root/multica_workspaces/<workspace_id>/<task_id>/workdir`
5. Daemon startet `claude` als Subprocess in diesem Verzeichnis

**Daemon-Log beobachten:**
```bash
wsl multica daemon logs 2>&1 | tail -20
# Live-Beobachtung (grep nach task-pickup):
wsl multica daemon logs 2>&1 | grep -E "(task received|picked task|finished|failed)"
```

---

## Schritt 3: Status prüfen

```bash
# Issue-Status abrufen
wsl multica issue get <ISSUE_ID> --output json

# Execution-History des Issues
wsl multica issue runs <ISSUE_ID> --output json

# Alle Issues im Workspace
wsl multica issue list

# Offene Issues suchen
wsl multica issue search "TypeScript"
```

Issue-Status-Werte:
- `backlog` — angelegt, wartet
- `todo` — aufgenommen / zugewiesen
- `in_progress` — Daemon arbeitet gerade daran
- `done` — erfolgreich abgeschlossen
- `cancelled` — abgebrochen

Status manuell setzen (falls nötig):
```bash
wsl multica issue status <ISSUE_ID> todo
wsl multica issue status <ISSUE_ID> done
```

---

## Schritt 4: Ergebnisse prüfen

Nach erfolgreicher Ausführung:

```bash
# Execution-Messages (AI-Antworten, Tool-Calls)
wsl multica issue run-messages <ISSUE_ID>

# Execution-Runs (alle Versuche mit Timing)
wsl multica issue runs <ISSUE_ID> --output json
```

Der Claude-Agent committet Änderungen direkt ins Repo. Prüfe daher auch:
```bash
cd C:\Users\botrunner\projects\AI-Company\dev-pool
git log --oneline -10
git diff HEAD~1
```

---

## Bekannte Einschränkung: Root-Problem in WSL

**Problem:** Der Daemon läuft in WSL als `root`. Claude Code verweigert
`--dangerously-skip-permissions` unter root aus Sicherheitsgründen.

**Fehler im Daemon-Log:**
```
--dangerously-skip-permissions cannot be used with root/sudo privileges for security reasons
claude finished — status=failed
```

**Lösungen:**

### Option A: Daemon als Non-Root-User starten (empfohlen)

```bash
# In WSL als non-root user einloggen
wsl -u botrunner

# Daemon stoppen (als root)
wsl multica daemon stop

# Als botrunner neu starten
wsl -u botrunner -- multica daemon start

# Status prüfen
wsl multica daemon status
```

### Option B: WSL-Standard-User auf non-root setzen

In `/etc/wsl.conf` (in WSL):
```ini
[user]
default=botrunner
```
Dann `wsl --shutdown` in PowerShell und WSL neu starten.

### Option C: Claude ohne --dangerously-skip-permissions

Über den Agenten-Instructions angeben, welche spezifischen Tools erlaubt sind,
damit Claude in einem restriktiveren Modus läuft.

---

## CTO-Agent konfigurieren

Der CTO-Agent wurde mit folgenden Instructions erstellt:

```
Du bist der CTO von AI_Studioxyz. Du bearbeitest Coding-Tasks im Repository
unter /home/botrunner/projects/AI-Company/dev-pool. Lese immer zuerst AGENTS.md
und CLAUDE.md. Arbeite nach den dort definierten Coding-Regeln. Erstelle atomic
commits im Conventional-Commits-Format. Führe nach jeder Änderung 'make check'
aus und fixe alle Fehler bevor du fertig bist.
```

Instructions aktualisieren:
```bash
wsl multica agent update b90d7546-83a4-4a89-9f99-b6a272967fcd \
  --instructions "Neue Instructions hier..."
```

Skills hinzufügen (z.B. für TypeScript-spezifische Patterns):
```bash
wsl multica agent skills b90d7546-83a4-4a89-9f99-b6a272967fcd
```

---

## CTO-Agent vom Python-Code aus nutzen

Das Tool `agents/cto/tools/devpool_tool.py` abstrahiert die REST API.
Benötigte Umgebungsvariablen in `agents/cto/.env`:

```bash
DEVPOOL_URL=https://api.multica.ai
DEVPOOL_TOKEN=mul_3ad12ff6...          # aus: wsl multica auth status
DEVPOOL_WORKSPACE_ID=7dc3f131-842b-4fa5-ad59-15b7b309064c
```

Nutzung im CTO-Agenten-Code:
```python
from tools.devpool_tool import DevPoolTool

tool = DevPoolTool()

# Task anlegen und CTO-Agent zuweisen
issue = tool.create_task(
    title="Fix TypeScript type errors in apps/web",
    description="Führe pnpm typecheck aus und behebe alle Fehler...",
    priority="high",
    assign_to_agent=True,   # findet automatisch einen Agent
)
print(f"Task angelegt: {issue['id']}")

# Status prüfen
status = tool.get_task_status(issue["id"])
print(f"Status: {status['status']}")
```

**Hinweis:** `DevPoolTool._get_available_agent()` sucht nach `status=idle`-Agenten
via `/api/agents`. Stelle sicher, dass der CTO-Agent im Workspace sichtbar ist
(`--visibility workspace`).

---

## Quick-Reference: Wichtige IDs

```
Workspace-ID:   7dc3f131-842b-4fa5-ad59-15b7b309064c
Runtime-ID:     ea1c94d5-3820-45c5-80da-89012d337ea5
CTO-Agent-ID:   b90d7546-83a4-4a89-9f99-b6a272967fcd
```

## Vollständiger Workflow auf einen Blick

```bash
# 1. Voraussetzungen prüfen
wsl multica daemon status
wsl multica agent list

# 2. Issue anlegen
wsl multica issue create \
  --title "Fix TypeScript type errors in apps/web" \
  --description "pnpm typecheck ausführen, alle Fehler beheben, committen." \
  --priority high \
  --assignee CTO

# 3. Daemon greift das Issue automatisch auf (alle ~3 Sek.)
wsl multica daemon logs 2>&1 | tail -5

# 4. Status verfolgen
wsl multica issue list
wsl multica issue runs <ISSUE_ID>

# 5. Ergebnis im Repo prüfen
git -C C:/Users/botrunner/projects/AI-Company/dev-pool log --oneline -5
```

---

## Test-Issue (bereits angelegt)

Beim Setup wurde folgendes Test-Issue angelegt und ausgeführt:

- **Title:** Test: CTO Agent Setup Verification
- **ID:** `6882defe-7220-4833-9f74-8753b1e89231`
- **Identifier:** SVE-1
- **Task-ID:** `9a4d1f74-0f40-4027-a93e-bbd7d67e7229`
- **Ergebnis:** `failed` — Daemon hat das Issue erkannt und Claude gestartet,
  aber Claude schlug fehl wegen des Root-Problems in WSL (siehe oben).
- **Nächster Schritt:** Daemon als Non-Root-User neu starten (Option A oben).
