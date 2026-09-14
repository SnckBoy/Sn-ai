# 🧠 Snck

<p align="center">
  <strong>Snck — AI Platform</strong>
</p>

<p align="center">
  A Snck-branded self-hosted AI workspace built on LibreChat, with third-party inference and local-model support.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Snck-AI-7C3AED?style=for-the-badge" alt="Snck">
  <img src="https://img.shields.io/badge/Self--Hosted-Ready-111827?style=for-the-badge" alt="Self Hosted">
  <img src="https://img.shields.io/badge/Docker-Supported-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker">
</p>

---

## ✨ About Snck

**Snck** is a Snck-branded deployment of the open-source **LibreChat** platform.

It combines AI conversations, agents, tools, files, web search, multimodal capabilities, third-party inference and local models in one self-hosted workspace.

### 🚀 Highlights

- 🤖 Multi-provider AI chat
- 🔑 User-provided third-party API keys
- 🌐 User-provided OpenAI-compatible API base URLs
- 🧠 AI Agents and MCP tools
- 🦙 Local AI models through the integrated local model service
- 📁 File and multimodal conversations
- 💻 Code Interpreter workflows
- 🔎 Web search
- 👥 Multi-user authentication
- 🎛️ Existing admin and permission system
- 🐳 Docker-based deployment
- ⚡ One-command Ubuntu VPS installer
- 🔐 Self-hosted infrastructure

---

## ⚡ One-Command Ubuntu VPS Install

On an Ubuntu VPS, run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/SnckBoy/Sn-ai/admin/retention-mode/install.sh)
```

The installer checks Ubuntu and Docker prerequisites, builds the integrated Snck API, and starts the Snck services including the private local model service.

After installation, open:

```text
http://YOUR-VPS-IP:3080
```

> 💡 For production, use a domain with HTTPS and a reverse proxy instead of exposing port `3080` directly.

---

## 🔑 Connect a Third-Party AI API

Snck includes a **Custom API** endpoint that lets each user connect their own OpenAI-compatible inference provider from the UI.

The endpoint supports:

- Your own API key
- Your own API base URL
- OpenAI-compatible gateways
- Model discovery when the provider exposes `/v1/models`
- Per-user credentials without putting provider keys in this repository

### Setup

1. Select **Snck Custom API** in the model/endpoint selector.
2. Enter your provider's API key.
3. Enter the provider's OpenAI-compatible base URL.
4. Select an available model.
5. Start chatting.

The provider should implement the OpenAI-compatible `/v1/models` and chat-completions interfaces. Provider-specific APIs may require a dedicated endpoint configuration.

---

## 🦙 Local AI

Snck includes a private local model service in the Docker deployment.

The local endpoint is available inside the Docker network and is not published as a public host port. Administrators can manage models through authenticated Snck admin routes.

Model-management routes:

```text
GET    /api/admin/snck/health
GET    /api/admin/snck/models
POST   /api/admin/snck/models/pull
DELETE /api/admin/snck/models/:model
```

Model names are validated and model operations communicate with the local model service over HTTP. The web application does not expose arbitrary shell execution.

---

## 🔐 Snck API

Snck uses the existing authenticated Remote Agents API-key system instead of introducing a second authentication database.

Enablement is configured in `librechat.yaml`:

```yaml
interface:
  remoteAgents:
    use: true
    create: true
```

OpenAI-compatible API routes are available at:

```text
GET  /api/agents/v1/models
POST /api/agents/v1/chat/completions
```

Example:

```bash
curl https://YOUR-SNCK-HOST/api/agents/v1/models \
  -H "Authorization: Bearer YOUR_SNCK_API_KEY"
```

API keys are managed through Snck's existing authenticated API-key system and are never committed to GitHub.

---

## 🛠️ Manual Docker Setup

```bash
git clone -b admin/retention-mode https://github.com/SnckBoy/Sn-ai.git
cd Sn-ai
cp .env.example .env
docker compose build api
docker compose up -d
```

Check services:

```bash
docker compose ps
```

View API logs:

```bash
docker compose logs -f api
```

View local-model logs:

```bash
docker compose logs -f ollama
```

---

## 🔧 Configuration

- `.env` — server-level configuration and secrets
- `librechat.yaml` — Snck endpoints and advanced configuration
- `docker-compose.override.yml` — local API build and private local-model service
- `config/snck.env.example` — Snck-specific environment examples

After configuration changes:

```bash
docker compose down
docker compose up -d
```

**Never commit API keys, passwords, tokens, database credentials, or other secrets to GitHub.**

---

## 📦 Project

```text
Sn-ai/
├── client/                     # Existing web client
├── api/                        # Existing backend/API
├── api/server/routes/admin/snck.js # Admin local-model controls
├── api/server/routes/snckApi.js     # Snck inference API module
├── packages/                   # Existing shared packages
├── config/                     # Configuration examples
├── librechat.yaml              # Snck endpoint configuration
├── docker-compose.yml          # Existing Docker deployment
├── docker-compose.override.yml # Snck integration layer
├── install.sh                  # Ubuntu VPS installer
└── README.md                   # Snck documentation
```

---

## 🌐 Links

- **Snck repository:** https://github.com/SnckBoy/Sn-ai
- **LibreChat documentation:** https://www.librechat.ai/docs
- **LibreChat upstream:** https://github.com/danny-avila/LibreChat

Snck builds upon LibreChat. Please retain applicable upstream license notices and attribution when modifying or redistributing the project.

---

## 📜 License

This repository contains open-source software derived from LibreChat. See the included license files and upstream LibreChat licensing information for the applicable terms.

---

<p align="center">
  <strong>⚡ Snck — Simple. Powerful. Self-hosted.</strong>
</p>
