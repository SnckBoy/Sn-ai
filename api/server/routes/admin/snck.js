const express = require('express');
const { SystemCapabilities } = require('@librechat/data-schemas');
const { requireCapability } = require('~/server/middleware/roles/capabilities');
const { requireJwtAuth } = require('~/server/middleware');

const router = express.Router();
const requireAdminAccess = requireCapability(SystemCapabilities.ACCESS_ADMIN);

const OLLAMA_BASE_URL = (process.env.OLLAMA_BASE_URL || 'http://ollama:11434').replace(/\/$/, '');
const MODEL_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:/-]{0,199}$/;

async function ollama(path, options = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), options.timeout ?? 30_000);
  try {
    const response = await fetch(`${OLLAMA_BASE_URL}${path}`, {
      ...options,
      signal: controller.signal,
      headers: { 'content-type': 'application/json', ...(options.headers || {}) },
    });
    const text = await response.text();
    let data;
    try {
      data = text ? JSON.parse(text) : {};
    } catch {
      data = { output: text.slice(-4000) };
    }
    if (!response.ok) {
      const message = data?.error || data?.message || `Ollama returned HTTP ${response.status}`;
      const error = new Error(message);
      error.status = response.status;
      throw error;
    }
    return data;
  } finally {
    clearTimeout(timeout);
  }
}

router.use(requireJwtAuth, requireAdminAccess);

router.get('/health', async (_req, res) => {
  try {
    const data = await ollama('/api/tags', { timeout: 5_000 });
    res.json({ ok: true, ollama: true, modelCount: data.models?.length ?? 0 });
  } catch (error) {
    res.status(502).json({ ok: false, ollama: false, error: error.message });
  }
});

router.get('/models', async (_req, res) => {
  try {
    const data = await ollama('/api/tags', { timeout: 15_000 });
    res.json({ models: data.models || [] });
  } catch (error) {
    res.status(502).json({ error: `Unable to reach local model service: ${error.message}` });
  }
});

router.post('/models/pull', async (req, res) => {
  const model = typeof req.body?.model === 'string' ? req.body.model.trim() : '';
  if (!MODEL_PATTERN.test(model) || model.includes('..')) {
    return res.status(400).json({ error: 'Invalid model name' });
  }

  try {
    const data = await ollama('/api/pull', {
      method: 'POST',
      body: JSON.stringify({ model, stream: false }),
      timeout: 30 * 60 * 1000,
    });
    return res.json({ installed: true, model, status: data.status || 'success' });
  } catch (error) {
    return res.status(error.status && error.status >= 400 ? error.status : 502).json({
      installed: false,
      model,
      error: error.message,
    });
  }
});

router.delete('/models/:model', async (req, res) => {
  const model = typeof req.params.model === 'string' ? req.params.model : '';
  if (!MODEL_PATTERN.test(model) || model.includes('..')) {
    return res.status(400).json({ error: 'Invalid model name' });
  }

  try {
    await ollama('/api/delete', {
      method: 'DELETE',
      body: JSON.stringify({ model }),
      timeout: 30_000,
    });
    return res.json({ deleted: true, model });
  } catch (error) {
    return res.status(error.status && error.status >= 400 ? error.status : 502).json({
      deleted: false,
      model,
      error: error.message,
    });
  }
});

module.exports = router;
