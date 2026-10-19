import { styleText } from 'node:util';
import { createUnico } from './api/unico.js';
import { createApp } from './app.js';
import { loadSettings } from './settings/settings.js';

const settings = loadSettings(process.env);
const unico = createUnico(settings);

// The Unico logo (lowercase, geometric), drawn from the brand SVG.
const banner = `
██      ██ ██▀▄███▄▄  ██  ▄▄████▄▄   ▄▄████▄▄
██      ██ ▀▄█▀   ▀█▄ ██ ▄█▀    ▀▀▀ ▄█▀    ▀█▄
██      ██ ██      ██ ██ ██         ██      ██
▀█▄    ▄█▀ ██      ██ ██ ▀█▄    ▄▄▄ ▀█▄    ▄█▀
 ▀▀████▀▀  ██      ██ ██  ▀▀████▀▀   ▀▀████▀▀`;

createApp({
  unico,
  publicUrl: settings.publicUrl,
  env: settings.env,
  serviceAccount: settings.serviceAccount,
}).listen(settings.port, () =>
  console.log(`${banner}

  Web reference app
  Unico ${settings.env.toUpperCase()}

  Open ${styleText('bold', settings.publicUrl)}
`),
);
