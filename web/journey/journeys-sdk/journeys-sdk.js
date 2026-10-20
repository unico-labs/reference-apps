// Journeys SDK: https://developer.unico.io/developers/sdks-and-tools/web
// The server answers the form post with journey.ejs, a page that imports unico-journey-sdk and opens the
// journey on top of it as the widget. onFinish sends the browser to the result page.
// Self-contained: the mode needs nothing outside this folder besides the shared page header and footer.
// The Express calls below are glue for this demo. The part to learn from is the script in journey.ejs.
import { fileURLToPath } from 'node:url';

export const label = 'Journeys SDK';

// The SDK's ES module build has no imports, so the browser loads it as is from node_modules, without a bundler.
const sdkFile = fileURLToPath(import.meta.resolve('unico-journey-sdk/index.esm.js'));

export function register(app) {
  app.get('/journeys-sdk/unico-journey-sdk.js', (_req, res) => res.sendFile(sdkFile));
}

// Only the process id and its token reach the page. The service account key stays on the server.
export function openJourney(res, process, { env, flow }) {
  res.render(`${import.meta.dirname}/journey.ejs`, { processId: process.id, token: process.token, env, flow, label });
}
