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

The installer handles the basic Docker deployment automatically and starts the Snck AI / LibreChat services.

After installation, open:

```text
http://YOUR-VPS-IP:3080
```

> 💡 For production, use a domain with HTTPS and a reverse proxy instead of exposing port `3080` directly.

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

Before production deployment, configure your AI provider credentials, authentication, database settings and other required environment variables.

**Never commit API keys, passwords, tokens or other secrets to GitHub.**

---

## 📦 Project

```text
Sn-ai/
├── client/             # Web client
├── api/                # Backend/API
├── packages/           # Shared packages
├── config/             # Configuration
├── .env.example        # Environment template
├── docker-compose.yml  # Docker deployment
├── install.sh          # Ubuntu VPS installer
└── README.md           # Snck AI documentation
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
