// Routes of the web app. Every page is rendered here, on the server, which also talks to Unico:
//   GET  /                 flows menu (?group=sign-up|step-up&region=all|global|brazil|mexico)
//   GET  /flows/{id}       create-process form
//   POST /flows/{id}       creates the process and opens the journey with the mode named in `journey`
//   GET  /result           the callbackUri: process JSON and selfie
//   GET  /result/evidenceset   evidence set PDF
// Each journey mode adds its own routes from its folder in journey/.
// Pages are EJS templates in views/. <%= %> escapes every value, so nothing Unico or the user sends is read as markup.
import { readdir, readFile } from 'node:fs/promises';
import { Readable } from 'node:stream';
import express from 'express';
import { InvalidInputError, UnicoError } from './api/unico.js';
import { buildProcessBody, filterFlows } from './flows/flows.js';
import { describe, processIdFrom, rememberProcess, sendEvidenceSet, showResult } from './result/result.js';

const flows = JSON.parse(await readFile(new URL('./flows/flows.json', import.meta.url)));

// Every folder in journey/ is a mode, loaded from the module of the same name. Deleting a folder removes the
// mode and its button, and the rest of the app keeps working.
const journeys = new Map();
for (const entry of await readdir(new URL('./journey/', import.meta.url), { withFileTypes: true })) {
  if (entry.isDirectory()) journeys.set(entry.name, await import(`./journey/${entry.name}/${entry.name}.js`));
}

// Create Process carries base64 documents and reference images. The docs don't set a request size limit,
// so 15 MB is a judgment call with room for a few document files. Lower it if your flows send no documents.
const MAX_BODY_BYTES = 15 * 1024 * 1024;

// Parses the form, multipart included, with the platform's own FormData parser. Files become base64 strings.
async function readFields(req) {
  const form = await new Request('http://localhost', {
    method: 'POST',
    headers: { 'Content-Type': req.headers['content-type'] ?? '' },
    body: Readable.toWeb(req),
    duplex: 'half',
  }).formData();

  const files = form.getAll('documentFiles').filter((file) => file.size > 0);
  const documentFiles = await Promise.all(
    files.map(async (file) => Buffer.from(await file.arrayBuffer()).toString('base64')),
  );
  return { ...Object.fromEntries(form), documentFiles };
}

export function createApp({ unico, publicUrl, env }) {
  const app = express();
  app.disable('x-powered-by');
  app.set('views', `${import.meta.dirname}/views`);
  app.set('view engine', 'ejs');
  app.use(express.static(`${import.meta.dirname}/public`));
  app.locals.journeys = journeys;
  for (const journey of journeys.values()) journey.register?.(app);

  app.get(['/', '/flows'], (req, res) => {
    const { group = 'sign-up', region = 'all' } = req.query;
    res.render('menu', { flows: filterFlows(flows, { group, region }), group, region });
  });

  app.param('id', (_req, res, next, id) => {
    res.locals.flow = flows.find((f) => f.id === id);
    if (!res.locals.flow) return res.status(404).render('not-found');
    next();
  });

  app.get('/flows/:id', (_req, res) => res.render('form', { error: undefined }));

  app.post('/flows/:id', async (req, res) => {
    // This server acts with the service account, so it only takes forms posted from its own pages.
    if (req.headers.origin && req.headers.origin !== new URL(publicUrl).origin) {
      const hint = `Forbidden: form posted from another site. Open the app at ${publicUrl} (PUBLIC_URL).`;
      return res.status(403).type('text').send(hint);
    }
    // Browsers send a length with every form post; anything without one, or above the limit, is refused.
    if (!(Number(req.headers['content-length']) <= MAX_BODY_BYTES)) {
      return res.status(413).type('text').send('Request body missing a length or larger than 15 MB');
    }

    let fields;
    try {
      fields = await readFields(req);
    } catch {
      return res.status(400).type('text').send('Bad request: expected a form (multipart/form-data or urlencoded)');
    }
    const journey = journeys.get(fields.journey);
    if (!journey) return res.status(400).type('text').send('Bad request: unknown journey mode');

    try {
      const body = buildProcessBody(res.locals.flow, fields, `${publicUrl}/result`);
      const { process } = await unico.createProcess(body);
      rememberProcess(res, process.id, publicUrl);
      journey.openJourney(res, process, { env });
    } catch (err) {
      res.status(err instanceof UnicoError ? err.status : 502).render('form', { error: describe(err) });
    }
  });

  app.get('/result', (req, res) => showResult(res, unico, processIdFrom(req)));
  app.get('/result/evidenceset', (req, res) => sendEvidenceSet(res, unico, processIdFrom(req)));

  app.use((_req, res) => res.status(404).render('not-found'));

  app.use((err, _req, res, _next) => {
    res.status(err instanceof InvalidInputError ? 400 : 500).render('error', { error: describe(err) });
  });

  return app;
}
