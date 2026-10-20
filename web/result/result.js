// The callbackUri page: shows the process as the API returns it, without interpreting it, plus the selfie
// and a link to the evidence set. The page itself is views/result.ejs.
import { InvalidInputError, UnicoError } from '../api/unico.js';

const COOKIE = 'unico_process_id';

// The callbackUri brings nothing back, so the process id travels in a cookie set on the way out to the
// journey. HttpOnly keeps it away from page scripts, and SameSite=Lax still sends it when Unico redirects back.
// A demo shortcut: in your app, put your own identifier in the callbackUri instead (see AGENTS.md).
export function rememberProcess(res, processId, publicUrl) {
  const secure = publicUrl.startsWith('https:') ? '; Secure' : '';
  res.setHeader('Set-Cookie', `${COOKIE}=${processId}; Path=/; HttpOnly; SameSite=Lax${secure}`);
}

export function processIdFrom(req) {
  return req.headers.cookie?.match(new RegExp(`(?:^|;\\s*)${COOKIE}=([^;]+)`))?.[1];
}

// Errors are shown raw too: status and body exactly as Unico returned them.
export function describe(error) {
  if (!(error instanceof UnicoError)) return String(error);
  const body = typeof error.body === 'string' ? error.body : JSON.stringify(error.body, null, 2);
  return `HTTP ${error.status}\n${body}`;
}

export async function showResult(res, unico, processId) {
  if (!processId) return res.render('result');

  // One GET each, once, after the callback. This repo's rule: no polling and no webhook.
  const [process, selfie] = await Promise.allSettled([unico.getProcess(processId), unico.getSelfie(processId)]);

  res.render('result', {
    processId,
    summary: process.value?.process,
    process: process.status === 'fulfilled' ? JSON.stringify(process.value, null, 2) : describe(process.reason),
    selfie:
      selfie.status === 'fulfilled'
        ? { src: `data:${selfie.value.contentType};base64,${selfie.value.fileContents}` }
        : { error: describe(selfie.reason) },
  });
}

// Sends the evidence set PDF itself, decoded from base64, so the browser opens it as a file.
// contentType comes back as "x-pdf", which browsers don't recognize, so the type is set here.
export async function sendEvidenceSet(res, unico, processId) {
  if (!processId) return res.status(404).render('result');
  try {
    const { fileContents } = await unico.getEvidenceSet(processId);
    res
      .type('application/pdf')
      .set('Content-Disposition', 'inline; filename="evidence-set.pdf"')
      .send(Buffer.from(fileContents, 'base64'));
  } catch (err) {
    const status = err instanceof InvalidInputError ? 400 : (err.status ?? 502);
    res.status(status).type('text').send(describe(err));
  }
}
