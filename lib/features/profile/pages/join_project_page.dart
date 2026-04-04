import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/page_container.dart';
import '../../../shared/widgets/pp_button.dart';
import '../../../shared/widgets/pp_input.dart';

/// Aceitar convite por código (Cloud Function `acceptInvite`).
class JoinProjectPage extends ConsumerStatefulWidget {
  const JoinProjectPage({super.key});

  @override
  ConsumerState<JoinProjectPage> createState() => _JoinProjectPageState();
}

class _JoinProjectPageState extends ConsumerState<JoinProjectPage> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Cole o código enviado pelo dono ou admin do projeto.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(profileServiceProvider).acceptInviteWithCallable(code);
      ref.invalidate(userProfilesProvider(FirebaseAuth.instance.currentUser!.uid));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você entrou no projeto. Escolha-o no seletor do hub.')),
      );
      context.go('/dashboard');
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _loading = false;
        _error = _messageForFunctionsException(e);
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  static String _messageForFunctionsException(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'not-found':
        return 'Código inválido ou convite removido.';
      case 'failed-precondition':
        return 'Convite expirado ou projeto indisponível.';
      case 'resource-exhausted':
        return 'Este convite já atingiu o número máximo de usos.';
      case 'unauthenticated':
        return 'Faça login e tente de novo.';
      default:
        return e.message ?? 'Não foi possível aceitar o convite.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrar em um projeto'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/perfil');
            }
          },
        ),
      ),
      body: PageContainer(
        maxWidth: 440,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Peça o código ao administrador da banda ou projeto. '
                'Cada integrante usa sua própria conta do app.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PPInput(
                label: 'Código do convite',
                controller: _codeCtrl,
                hint: 'Cole aqui',
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              PPButton(
                label: 'Entrar no projeto',
                icon: Icons.group_add_rounded,
                onPressed: _loading ? null : _submit,
                isLoading: _loading,
                fullWidth: true,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () {
                  final t = _codeCtrl.text.trim();
                  if (t.isEmpty) return;
                  Clipboard.setData(ClipboardData(text: t));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código copiado')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copiar campo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
