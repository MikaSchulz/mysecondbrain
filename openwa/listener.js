// listener.js — OpenWA: eingehende WhatsApp-Nachrichten -> /opt/kb/vault/raw/
//   Sprachnachrichten -> raw/audio/  (prep-raw transkribiert via whisper)
//   Text/Chats        -> raw/chats/<chat>.md (mit Frontmatter from/chat/date)
// EXPERIMENTELL. Inoffizielle WhatsApp-Automation -> gegen WhatsApp-ToS (Sperr-Risiko). Zweitnummer!
const fs = require('fs');
const path = require('path');
const { create, decryptMedia } = require('@open-wa/wa-automate');

const VAULT = process.env.VAULT || '/opt/kb/vault';
const RAW_AUDIO = path.join(VAULT, 'raw', 'audio');
const RAW_CHATS = path.join(VAULT, 'raw', 'chats');
for (const d of [RAW_AUDIO, RAW_CHATS]) fs.mkdirSync(d, { recursive: true });

const sanitize = (s) => String(s || 'chat').replace(/[^\w.-]/g, '_').slice(0, 60);

create({
  sessionId: 'kb',
  multiDevice: true,
  headless: true,
  qrTimeout: 0,
  authTimeout: 0,
  disableSpins: true,
  qrLogSkip: false,                 // QR in den Logs anzeigen (journalctl -u kb-openwa -f)
  sessionDataPath: '/opt/kb-openwa/sessions',
  executablePath: process.env.CHROME_PATH || undefined,
  cacheEnabled: false,
}).then(start).catch((e) => { console.error('create-Fehler:', e); process.exit(1); });

function start(client) {
  console.log('kb-openwa: Listener läuft.');
  client.onMessage(async (msg) => {
    try {
      const ts = new Date().toISOString().replace(/[:.]/g, '-');
      const isAudio = msg.mimetype && (msg.type === 'ptt' || msg.type === 'audio' || String(msg.mimetype).startsWith('audio'));
      if (isAudio) {
        const buf = await decryptMedia(msg);
        let ext = (String(msg.mimetype).split('/')[1] || 'ogg').split(';')[0];
        const idTail = (msg.id || 'wa').toString().split('_').pop();
        const f = path.join(RAW_AUDIO, `${ts}-${idTail}.${ext}`);
        fs.writeFileSync(f, buf);
        console.log('audio gespeichert:', f);
      } else if (msg.body) {
        const chat = sanitize(msg.chatId || msg.from);
        const f = path.join(RAW_CHATS, `${chat}.md`);
        const date = new Date((msg.timestamp || Date.now() / 1000) * 1000).toISOString();
        const sender = (msg.sender && (msg.sender.pushname || msg.sender.formattedName)) || msg.notifyName || msg.author || '?';
        const header = fs.existsSync(f) ? '' :
          `---\nfrom: "${sender}"\nchat: "${chat}"\ndate: ${date}\nsources: whatsapp\n---\n\n`;
        fs.appendFileSync(f, header + `**${sender}** (${date}): ${msg.body}\n`);
        console.log('chat-text angehängt:', f);
      }
    } catch (e) {
      console.error('onMessage-Fehler:', e);
    }
  });
}
