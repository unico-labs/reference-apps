import jwt from 'jsonwebtoken';

// https://developer.unico.io/developers/start/environments
export const HOSTS = {
  uat: { identity: 'https://identityhomolog.acesso.io', api: 'https://api.idcloud.uat.unico.app' },
  prod: { identity: 'https://identity.acesso.io', api: 'https://api.idcloud.unico.app' },
};

// The docs ask for proactive renewal when 10 minutes or less remain.
const RENEW_BEFORE_MS = 10 * 60 * 1000;

// Any non-2xx answer from Unico, with the status and body exactly as returned.
export class UnicoError extends Error {
  constructor(status, body) {
    super(`Unico API returned ${status}`);
    this.status = status;
    this.body = body;
  }
}

// Bad input caught here, before anything is sent to Unico.
export class InvalidInputError extends Error {}

async function readJson(res) {
  const text = await res.text();
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

// Ids are interpolated into the URL, so anything like `../` is refused before calling Unico.
function processId(id) {
  if (typeof id !== 'string' || !/^[\w-]+$/.test(id)) throw new InvalidInputError('invalid process id');
  return id;
}

export function createUnico({ serviceAccount, privateKey, hosts }) {
  let cached;
  let pending;

  // https://developer.unico.io/developers/start/authentication
  async function requestToken() {
    const now = Math.floor(Date.now() / 1000);
    const assertion = jwt.sign(
      { iss: serviceAccount, aud: hosts.identity, scope: '*', iat: now, exp: now + 3600 },
      privateKey,
      { algorithm: 'RS256' },
    );

    const res = await fetch(`${hosts.identity}/oauth2/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
    });
    const data = await readJson(res);
    if (!res.ok) throw new UnicoError(res.status, data);

    cached = { accessToken: data.access_token, renewAt: Date.now() + data.expires_in * 1000 - RENEW_BEFORE_MS };
    return data.access_token;
  }

  function token() {
    if (cached && Date.now() < cached.renewAt) return Promise.resolve(cached.accessToken);
    // Concurrent callers share one request. Two assertions signed in the same second are identical,
    // and Unico refuses a reused JWT (error 1.2.7).
    pending ??= requestToken().finally(() => {
      pending = undefined;
    });
    return pending;
  }

  async function call(method, path, body) {
    const res = await fetch(`${hosts.api}${path}`, {
      method,
      headers: { Authorization: `Bearer ${await token()}`, 'Content-Type': 'application/json' },
      body: body && JSON.stringify(body),
    });
    const data = await readJson(res);
    if (!res.ok) throw new UnicoError(res.status, data);
    return data;
  }

  return {
    // https://developer.unico.io/developers/api-reference/post-processes → { process }
    createProcess: async (body) => call('POST', '/client/v1/process', body),
    // https://developer.unico.io/developers/api-reference/get-process → { process }
    getProcess: async (id) => call('GET', `/client/v1/process/${processId(id)}`),
    // https://developer.unico.io/developers/api-reference/get-selfie → { fileContents, contentType }
    getSelfie: async (id) => call('GET', `/client/v1/process/${processId(id)}/selfie`),
    // https://developer.unico.io/developers/api-reference/get-evidence-set → { fileContents, contentType }
    // fileContents is a base64 PDF. contentType comes back as "x-pdf", not "application/pdf": don't send it to a browser as is.
    getEvidenceSet: async (id) => call('GET', `/client/v1/process/${processId(id)}/evidenceset`),
  };
}
