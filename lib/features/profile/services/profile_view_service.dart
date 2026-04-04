import 'package:cloud_functions/cloud_functions.dart';

/// Incrementa visualizações da página pública (Cloud Function `recordProfileView`).
Future<void> recordPublicProfileView(String profileId) async {
  try {
    final callable = FirebaseFunctions.instance.httpsCallable('recordProfileView');
    await callable.call(<String, dynamic>{'profileId': profileId});
  } catch (_) {
    // Função ainda não deployada ou rede — ignora
  }
}
