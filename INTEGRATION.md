# Dev Pool — Integration in AI-Company

Multica läuft als interner **Coding Agent Pool** für AI_Studioxyz.  
Der CTO-Bot delegiert Coding-Tasks hierhin — Multica-Agenten (Claude Code / Codex) arbeiten sie autonom ab.

## Konzept

```
Paperclip (Geschäftsziele)
    └── CTO-Bot (agents/cto/agent.py)
            └── DevPoolTool (tools/devpool_tool.py)
                    └── Multica REST API (localhost:8080)
                            └── Coding Agents (Claude Code / Codex)
```

## Setup

### 1. Multica starten
```bash
cd dev-pool
cp .env.example .env
# .env anpassen: JWT_SECRET, DB-Verbindung etc.
docker compose up -d   # PostgreSQL starten
make setup             # DB migrieren
make start             # Backend (8080) + Frontend (3000)
```

### 2. Token holen
Im Multica-Dashboard unter Settings → API → Token generieren.  
In `AI-Company/.env` eintragen:
```
DEVPOOL_TOKEN=<dein-token>
DEVPOOL_WORKSPACE_ID=<workspace-id>
```

### 3. Multica CLI (optional, für lokalen Daemon)
```
Fetch https://github.com/multica-ai/multica/blob/main/CLI_INSTALL.md and follow the instructions to install Multica CLI, log in, and start the daemon on this machine.
```

## Verwendung im CTO-Agent

```python
from tools.devpool_tool import DevPoolTool

devpool = DevPoolTool()

# Prüfen ob erreichbar
if devpool.is_reachable():
    # Task delegieren
    issue = devpool.create_task(
        title="Homepage für Klient ABC",
        description="React + TailwindCSS, responsive, 3 Sektionen: Hero, Services, Contact",
        priority="high",
    )
    print(f"Task erstellt: #{issue['id']}")

    # Status abfragen
    status = devpool.get_task_status(issue["id"])
    print(f"Status: {status['status']}")
```

## Typische Use Cases für den CTO-Bot

| Aufgabe | Beispiel-Task |
|---|---|
| Kunden-Homepage | "Baue eine Landing Page für Klient X mit React" |
| API-Integration | "Integriere Stripe Checkout in Website" |
| Bug Fix | "Fix broken contact form on aistudioxyz.com" |
| Neuer Agent | "Erstelle Python-Agenten-Template für Use Case Y" |

## Ports

| Service | Port |
|---|---|
| Multica Backend API | 8080 |
| Multica Frontend | 3000 |
| PostgreSQL | 5432 |
