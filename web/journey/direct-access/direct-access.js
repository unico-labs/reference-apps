// Direct Access: https://developer.unico.io/developers/sdks-and-tools/web
// The server answers the form post with 303 See Other to userRedirectUrl, so the browser leaves for the
// journey in the same tab. When the journey ends, Unico sends it back to the callbackUri given at creation.
// Self-contained: the mode needs nothing outside this folder.

export const label = 'Redirect';

export function openJourney(res, process) {
  // Use the URL as returned, without changing it. Plain Node on purpose: Express's res.redirect re-encodes it.
  res.writeHead(303, { Location: process.userRedirectUrl }).end();
}
