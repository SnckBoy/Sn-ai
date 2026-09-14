# 🧠 Snck AI

<p align="center">
  <strong>Snck AI — Your Self-Hosted AI Workspace</strong>
</p>

<p align="center">
  A Snck-branded AI chat platform built on LibreChat, designed for simple deployment on your own Ubuntu VPS.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Snck-AI-7C3AED?style=for-the-badge" alt="Snck AI">
  <img src="https://img.shields.io/badge/Self--Hosted-Ready-111827?style=for-the-badge" alt="Self Hosted">
  <img src="https://img.shields.io/badge/Docker-Supported-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker">
</p>

---

## ✨ About Snck AI

**Snck AI** is a Snck-branded deployment of the open-source **LibreChat** platform.

It brings AI conversations, agents, tools, files, web search, multimodal capabilities and administration into one self-hosted workspace.

### 🚀 Highlights

- 🤖 Multi-provider AI chat
- 🔑 **User-provided third-party API keys**
- 🌐 **User-provided OpenAI-compatible API base URLs**
- 🧠 AI Agents and MCP tools
- 📁 File and multimodal conversations
- 💻 Code Interpreter workflows
- 🔎 Web search
- 👥 Multi-user authentication
- 🎛️ Administration features
- 🐳 Docker-based deployment
- ⚡ One-command Ubuntu VPS installer
- 🔐 Self-hosted infrastructure

---

## ⚡ One-Command Ubuntu VPS Install

On an Ubuntu VPS, run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/SnckBoy/Sn-ai/admin/retention-mode/install.sh)
```

The installer handles the basic Docker deployment automatically and starts the Snck AI services.

After installation, open:

```text
http://YOUR-VPS-IP:3080
```

> 💡 For production, use a domain with HTTPS and a reverse proxy instead of exposing port `3080` directly.

---

## 🔑 Connect a Third-Party AI API

Snck AI now includes a **Custom API** endpoint that lets each user connect their own compatible inference provider from the LibreChat UI.

The custom endpoint supports:

- Your own API key
- Your own API base URL
- OpenAI-compatible gateways
- Automatic model discovery when the provider exposes `/v1/models`
- Per-user credentials without putting the key in this GitHub repository

### Example

Use an OpenAI-compatible provider with a base URL such as:

```text
https://example-provider.com/v1
```

Then in Snck AI:

1. Select **Snck AI • Custom API**.
2. Enter your provider's **API key** when prompted.
3. Enter the provider's **API base URL** if prompted.
4. Choose one of the models returned by the provider.
5. Start chatting.

> The provider must expose an API compatible with the OpenAI chat-completions interface. Providers using a completely different API format need a dedicated endpoint configuration.

### 🔒 Security

Snck AI uses LibreChat's `user_provided` endpoint configuration for this feature. User API keys are not hardcoded into `librechat.yaml` or committed to GitHub.

---

## 🛠️ Manual Docker Setup

```bash
git clone https://github.com/SnckBoy/Sn-ai.git
cd Sn-ai
cp .env.example .env
docker compose up -d
```

Check the services:

```bash
docker compose ps
```

View logs:

```bash
docker compose logs -f
```

---

## 🔧 Configuration

Snck AI uses the LibreChat environment and configuration files included in this repository.

- `.env` — server-level configuration and secrets
- `librechat.yaml` — custom endpoints and advanced configuration
- `docker-compose.override.yml` — mounts the custom configuration into the API container

After changing configuration, restart the stack:

```bash
docker compose down
docker compose up -d
```

**Never commit API keys, passwords, tokens or other secrets to GitHub.**

---

## 📦 Project

```text
Sn-ai/
├── client/                    # Web client
├── api/                       # Backend/API
├── packages/                  # Shared packages
├── config/                    # Configuration
├── librechat.yaml             # Snck AI custom API endpoint
├── docker-compose.yml         # Docker deployment
├── docker-compose.override.yml # Custom config mount
├── .env.example               # Environment template
├── install.sh                 # Ubuntu VPS installer
└── README.md                  # Snck AI documentation
```

---

## 🌐 Links

- **Snck AI repository:** https://github.com/SnckBoy/Sn-ai
- **LibreChat documentation:** https://www.librechat.ai/docs
- **LibreChat upstream:** https://github.com/danny-avila/LibreChat

Snck AI builds upon LibreChat. Please retain applicable upstream license notices and attribution when modifying or redistributing the project.

---

## 📜 License

This repository contains open-source software derived from LibreChat. See the included license files and upstream LibreChat licensing information for the applicable terms.

---

<p align="center">
  <strong>⚡ Snck AI — Simple. Powerful. Self-hosted.</strong>
</p>
