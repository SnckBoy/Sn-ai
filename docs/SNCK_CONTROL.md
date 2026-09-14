# Snck — AI Platform Control Features

The supplied `ollama-main-snck-features.zip` was integrated into the existing Snck architecture rather than copied over the application. The existing authentication, permissions, API-key storage, and custom-endpoint system remain the source of truth.

## Custom third-party inference

`librechat.yaml` exposes **Snck Custom API** with:

```yaml
apiKey: "user_provided"
baseURL: "user_provided"
```

Each user can enter their own OpenAI-compatible API key and base URL from the Snck UI. The key is handled by LibreChat's existing encrypted user-key storage rather than a new plaintext database.

## Snck API keys

Remote Agents API key management is enabled with:

```yaml
interface:
  remoteAgents:
    use: true
    create: true
```

Users with the appropriate Remote Agents permission can create and revoke API keys from Snck. Admins retain the existing administrator permissions.

The existing authenticated OpenAI-compatible API is available at:

```text
/api/agents/v1/models
/api/agents/v1/chat/completions
```

Example:

```bash
curl https://YOUR_SNCK_HOST/api/agents/v1/models \
  -H "Authorization: Bearer YOUR_SNCK_API_KEY"
```

The API key is never placed in the frontend bundle or repository.

## Local models

Snck now includes an internal local model service in the Docker deployment. It is not exposed directly on a public host port.

The Snck Local endpoint uses:

```text
http://ollama:11434/v1/
```

Admins can manage local models through authenticated backend routes under the existing admin users route:

```text
GET    /api/admin/users/snck/health
GET    /api/admin/users/snck/models
POST   /api/admin/users/snck/models/pull
DELETE /api/admin/users/snck/models/:model
```

Model names are validated and the integration communicates with the local model service over HTTP. It does not expose a generic shell-command endpoint.

## Environment

The Docker API container uses:

```text
OLLAMA_BASE_URL=http://ollama:11434
```

For an external/private Ollama service, set `OLLAMA_BASE_URL` to the service address in the deployment environment instead of exposing the service publicly.

See `config/snck.env.example` for the Snck-specific deployment variables.

## Security

- Admin local-model routes require the existing JWT authentication and `ACCESS_ADMIN` capability.
- Remote API routes use the existing Remote Agents API-key authentication and permissions.
- User-provided third-party API keys use the existing encrypted credential storage.
- Model names are validated before requests are sent to the local model service.
- No web endpoint executes arbitrary shell commands.
- Do not commit `.env`, API keys, JWT secrets, database credentials, or provider credentials.
