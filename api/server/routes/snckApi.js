const express = require('express');
const {
  requireRemoteAgentAuth,
  checkRemoteAgentsFeature,
} = require('./agents/middleware');
const { configMiddleware, messageIpLimiter, messageUserLimiter } = require('~/server/middleware');

const router = express.Router();
const OLLAMA_BASE_URL = (process.env.OLLAMA_BASE_URL || 'http://ollama:11434').replace(/\/$/, '');
const MODEL_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:/-]{0,199}$/;

function validateModel(model) {
  return typeof model === 'string' && MODEL_PATTERN.test(model) && !model.includes('..');
}

async function ollama(path, body) {
  const response = await fetch(`${OLLAMA_BASE_URL}${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(text.slice(-2000) || `Ollama returned HTTP ${response.status}`);
  }
  return response;
}

router.use(requireRemoteAgentAuth, configMiddleware, checkRemoteAgentsFeature);

router.get('/models', async (_req, res) => {
  try {
    const response = await fetch(`${OLLAMA_BASE_URL}/api/tags`, { signal: AbortSignal.timeout(15_000) });
    if (!response.ok) return res.status(502).json({ error: 'Local model service unavailable' });
    const data = await response.json();
    return res.json({
      object: 'list',
      data: (data.models || []).map((model) => ({
        id: model.name,
        object: 'model',
        owned_by: 'local',
      })),
    });
  } catch (error) {
    return res.status(502).json({ error: `Local model service unavailable: ${error.message}` });
  }
});

router.post('/chat/completions', messageIpLimiter, messageUserLimiter, async (req, res) => {
  const { model, messages, stream = false, options = {} } = req.body || {};
  if (!validateModel(model) || !Array.isArray(messages)) {
    return res.status(400).json({ error: { message: 'A valid model and messages array are required', type: 'invalid_request_error' } });
  }

  try {
    const upstream = await ollama('/api/chat', { model, messages, stream: Boolean(stream), options });

    if (!stream) {
      const data = await upstream.json();
      const content = data?.message?.content || '';
      return res.json({
        id: `chatcmpl-snck-${Date.now()}`,
        object: 'chat.completion',
        model,
        choices: [{ index: 0, message: { role: 'assistant', content }, finish_reason: 'stop' }],
        usage: {},
      });
    }

    res.status(200);
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    const reader = upstream.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';
    let sentRole = false;

    const send = (payload) => res.write(`data: ${JSON.stringify(payload)}\n\n`);

    while (true) {
      const { done, value } = await reader.read();
      buffer += decoder.decode(value || new Uint8Array(), { stream: !done });
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';

      for (const line of lines) {
        if (!line.trim()) continue;
        const chunk = JSON.parse(line);
        const content = chunk?.message?.content || '';
        const delta = sentRole ? { content } : { role: 'assistant', content };
        sentRole = true;
        send({ id: `chatcmpl-snck-${Date.now()}`, object: 'chat.completion.chunk', model, choices: [{ index: 0, delta, finish_reason: chunk.done ? 'stop' : null }] });
      }
      if (done) break;
    }
    send('[DONE]');
    return res.end();
  } catch (error) {
    if (!res.headersSent) return res.status(502).json({ error: { message: error.message, type: 'upstream_error' } });
    return res.end();
  }
});

router.post('/completions', messageIpLimiter, messageUserLimiter, async (req, res) => {
  const { model, prompt = '', stream = false, options = {} } = req.body || {};
  if (!validateModel(model)) {
    return res.status(400).json({ error: { message: 'A valid model is required', type: 'invalid_request_error' } });
  }

  try {
    const upstream = await ollama('/api/generate', { model, prompt, stream: Boolean(stream), options });
    if (stream) {
      res.status(200).set({ 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', Connection: 'keep-alive' });
      const reader = upstream.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';
      while (true) {
        const { done, value } = await reader.read();
        buffer += decoder.decode(value || new Uint8Array(), { stream: !done });
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';
        for (const line of lines) {
          if (!line.trim()) continue;
          const chunk = JSON.parse(line);
          res.write(`data: ${JSON.stringify({ id: `cmpl-snck-${Date.now()}`, object: 'text_completion', model, choices: [{ text: chunk.response || '', index: 0, finish_reason: chunk.done ? 'stop' : null }] })}\n\n`);
        }
        if (done) break;
      }
      res.write('data: [DONE]\n\n');
      return res.end();
    }

    const data = await upstream.json();
    return res.json({ id: `cmpl-snck-${Date.now()}`, object: 'text_completion', model, choices: [{ text: data.response || '', index: 0, finish_reason: 'stop' }], usage: {} });
  } catch (error) {
    return res.status(502).json({ error: { message: error.message, type: 'upstream_error' } });
  }
});

module.exports = router;
