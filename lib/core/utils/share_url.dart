/// Base do site (sempre path real, sem `#`), para links que o Hosting precisa resolver.
String _siteOrigin() => Uri.base.origin;

/// URL da SPA (Flutter) — abre o app em `/artist/:id`.
/// Usa só `origin` + path para funcionar com Hosting (`**` → index.html) e path URL strategy.
String artistPublicPageUrl(String profileId) {
  return '${_siteOrigin()}/artist/$profileId';
}

/// URL para WhatsApp/Instagram: path `/share/artist/...` (Hosting → Cloud Function).
/// Query `id` duplica o id: na CF v2 o path às vezes não chega inteiro; a função aceita `?id=`.
/// Nunca use fragmento `#/share/...` — o servidor não recebe o que vem depois de `#`.
String artistSocialShareUrl(String profileId) {
  final q = Uri.encodeQueryComponent(profileId);
  return '${_siteOrigin()}/share/artist/$profileId?id=$q';
}
