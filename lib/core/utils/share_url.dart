/// URL compartilhável da página pública do artista (web).
/// Com `usePathUrlStrategy`, use `origin + /artist/:id`. Caso contrário, ajuste o deploy ou o hash conforme o host.
String artistPublicPageUrl(String profileId) {
  final base = Uri.base;
  final path = '/artist/$profileId';
  if (base.fragment.isNotEmpty) {
    return '${base.origin}${base.path}#$path';
  }
  return '${base.origin}$path';
}
