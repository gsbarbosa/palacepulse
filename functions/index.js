/**
 * Deploy: firebase deploy --only functions
 * Config e-mail (Resend): firebase functions:config:set resend.key="re_xxx"
 * Domínio "from" deve estar verificado no Resend.
 */
const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

admin.initializeApp();

/** Hosting às vezes encaminha com req.path === '/'; tentar várias fontes. */
function extractProfileIdFromRequest(req) {
  const chunks = [
    req.path,
    req.url,
    req.originalUrl,
    req.get('x-forwarded-uri'),
    req.get('x-forwarded-url'),
    req.get('x-original-url'),
    req.get('x-firebase-hosting-path'),
  ]
    .filter(Boolean)
    .map((s) => String(s).split('?')[0].split('#')[0]);
  for (const c of chunks) {
    const m = c.match(/\/share\/artist\/([^/?]+)/);
    if (m) return m[1];
    const m2 = c.match(/share\/artist\/([^/?]+)/);
    if (m2) return m2[1];
  }
  const q = req.query && (req.query.id || req.query.profileId);
  if (q && typeof q === 'string' && q.length < 129) return q;
  return null;
}

function escHtml(s) {
  if (s == null || s === undefined) return '';
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * Aceita convite de projeto: grava user_profile_access e profile_members e incrementa uses.
 */
exports.acceptInvite = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Faça login para aceitar o convite');
  }
  const token = data && data.token;
  if (!token || typeof token !== 'string' || token.length < 8 || token.length > 64) {
    throw new functions.https.HttpsError('invalid-argument', 'Código de convite inválido');
  }
  const uid = context.auth.uid;
  const db = admin.database();
  const invRef = db.ref(`invite_by_code/${token}`);
  const snap = await invRef.once('value');
  if (!snap.exists()) {
    throw new functions.https.HttpsError('not-found', 'Convite não encontrado');
  }
  const inv = snap.val();
  const profileId = inv.profileId;
  const role = inv.role === 'admin' || inv.role === 'viewer' ? inv.role : 'editor';
  const maxUses = typeof inv.maxUses === 'number' ? inv.maxUses : 30;
  let uses = typeof inv.uses === 'number' ? inv.uses : 0;
  const expiresAt = inv.expiresAt;
  if (!profileId || typeof profileId !== 'string') {
    throw new functions.https.HttpsError('failed-precondition', 'Convite corrompido');
  }
  if (expiresAt != null && typeof expiresAt === 'number' && Date.now() > expiresAt) {
    throw new functions.https.HttpsError('failed-precondition', 'Este convite expirou');
  }
  if (uses >= maxUses) {
    throw new functions.https.HttpsError('resource-exhausted', 'Este convite atingiu o limite de usos');
  }
  const profSnap = await db.ref(`profiles/${profileId}`).once('value');
  if (!profSnap.exists()) {
    throw new functions.https.HttpsError('not-found', 'Projeto não existe mais');
  }
  const ownerId = profSnap.val().ownerUserId;
  if (ownerId === uid) {
    return { ok: true, profileId, alreadyOwner: true };
  }
  const accessSnap = await db.ref(`user_profile_access/${uid}/${profileId}`).once('value');
  if (accessSnap.exists()) {
    return { ok: true, profileId, alreadyMember: true };
  }
  const joinedAt = new Date().toISOString();
  const updates = {};
  updates[`user_profile_access/${uid}/${profileId}`] = { role, joinedAt };
  updates[`profile_members/${profileId}/${uid}`] = { role, joinedAt };
  updates[`invite_by_code/${token}/uses`] = uses + 1;
  await db.ref().update(updates);
  return { ok: true, profileId, role };
});

/** Incrementa stats/profile_views/{profileId} */
exports.recordProfileView = functions.https.onCall(async (data) => {
  const profileId = data.profileId;
  if (!profileId || typeof profileId !== 'string' || profileId.length > 128) {
    throw new functions.https.HttpsError('invalid-argument', 'profileId inválido');
  }
  const snap = await admin.database().ref(`profiles/${profileId}`).once('value');
  if (!snap.exists()) {
    throw new functions.https.HttpsError('not-found', 'Perfil não encontrado');
  }
  const p = snap.val();
  if (p.status !== 'active' || p.publicProfile === false) {
    return { ok: false, reason: 'not_public' };
  }
  const ref = admin.database().ref(`stats/profile_views/${profileId}`);
  await ref.transaction((current) => (current || 0) + 1);
  return { ok: true };
});

/**
 * HTML com Open Graph para WhatsApp/Instagram.
 * Hosting rewrite: /share/artist/** → esta função
 */
exports.artistShare = functions.https.onRequest(async (req, res) => {
  res.set('Cache-Control', 'public, max-age=120, s-maxage=300');
  const host = req.get('host') || 'localhost';
  const proto = req.get('x-forwarded-proto') || 'https';
  const baseUrl = `${proto}://${host}`;

  const profileId = extractProfileIdFromRequest(req);
  if (!profileId) {
    res.status(404).send('<!DOCTYPE html><html><body>Link inválido</body></html>');
    return;
  }

  const snap = await admin.database().ref(`profiles/${profileId}`).once('value');
  if (!snap.exists()) {
    res.status(404).send('<!DOCTYPE html><html><body>Perfil não encontrado</body></html>');
    return;
  }
  const p = snap.val();
  if (p.status !== 'active' || p.publicProfile === false) {
    res.status(404).send('<!DOCTYPE html><html><body>Perfil indisponível</body></html>');
    return;
  }

  const title = escHtml(p.artistName || 'Music Map');
  const city = p.city || '';
  const state = p.state || '';
  const desc = `${city}${city && state ? ' – ' : ''}${state} · ${p.genre || 'Artista'} no Music Map`;
  const photo = p.photoUrl && String(p.photoUrl).trim() ? String(p.photoUrl).trim() : '';
  const shareUrl = `${baseUrl}/share/artist/${profileId}`;
  const appUrl = `${baseUrl}/artist/${profileId}`;

  const ogImageTags = photo
    ? `<meta property="og:image" content="${escHtml(photo)}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:image" content="${escHtml(photo)}">`
    : `<meta name="twitter:card" content="summary">`;

  const html = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} · Music Map</title>
<meta name="description" content="${escHtml(desc)}">
<meta property="og:title" content="${title} · Music Map">
<meta property="og:description" content="${escHtml(desc)}">
${ogImageTags}
<meta property="og:url" content="${escHtml(shareUrl)}">
<meta property="og:type" content="profile">
<meta name="twitter:title" content="${title}">
<meta name="twitter:description" content="${escHtml(desc)}">
<meta http-equiv="refresh" content="0;url=${escHtml(appUrl)}">
</head>
<body>
<p>Redirecionando para <a href="${escHtml(appUrl)}">${title}</a>…</p>
</body>
</html>`;
  res.set('Content-Type', 'text/html; charset=utf-8');
  res.status(200).send(html);
});

/** E-mail de boas-vindas (Resend). Config: firebase functions:config:set resend.key="re_xxx" */
exports.onAuthUserCreate = functions.auth.user().onCreate(async (user) => {
  const resendKey =
    process.env.RESEND_API_KEY ||
    (functions.config().resend && functions.config().resend.key);
  if (!resendKey) {
    console.log('Welcome email: defina RESEND_API_KEY ou functions.config().resend.key');
    return;
  }
  const email = user.email;
  if (!email) return;

  const from =
    process.env.RESEND_FROM || 'Music Map <onboarding@resend.dev>';

  try {
    const r = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${resendKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from,
        to: [email],
        subject: 'Bem-vindo ao Music Map',
        html:
          '<p>Olá!</p>' +
          '<p>Você entrou na <strong>cena fundadora</strong> do Music Map.</p>' +
          '<p>Complete seu perfil para aparecer no mapa e use o link público para compartilhar nas redes.</p>' +
          '<p>— Equipe Music Map</p>',
      }),
    });
    if (!r.ok) {
      const t = await r.text();
      console.error('Resend error', r.status, t);
    }
  } catch (e) {
    console.error('Welcome email failed', e);
  }
});
