import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/profile_completion.dart';
import '../../../core/utils/share_url.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/widgets/pp_badge.dart';
import '../../../shared/widgets/pp_card.dart';

/// Barra de progresso, checklist e mini missões
class ProfileGamificationSection extends StatelessWidget {
  final UserProfile profile;

  const ProfileGamificationSection({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final c = ProfileCompletion.fromProfile(profile);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PPCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Progresso do perfil',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: c.percent / 100,
                  minHeight: 10,
                  backgroundColor: AppColors.surfaceSecondary,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${c.percent}% completo',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const Divider(height: 24),
              Text('Checklist', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _checkRow('Perfil básico (nome, cidade, gênero, contato, Instagram)', c.basicComplete),
              _checkRow('Bio preenchida', c.bioComplete),
              _checkRow('Redes de streaming (Spotify / YouTube / TikTok)', c.streamingComplete),
              _checkRow('Interesses selecionados', c.interestsComplete),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PPCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PPBadge(label: 'Early Access', variant: PPBadgeVariant.primary),
                  PPBadge(label: 'Cena fundadora', variant: PPBadgeVariant.secondary),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PPCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mini missões',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _mission(
                context,
                'Atualize sua bio com seu último lançamento.',
                c.bioComplete,
              ),
              _mission(
                context,
                'Confirme se suas redes e contato ainda estão corretos.',
                c.basicComplete,
              ),
              _mission(
                context,
                'Escolha seus interesses (shows, collabs, etc.).',
                c.interestsComplete,
              ),
              if (c.allComplete) ...[
                const SizedBox(height: 12),
                Text(
                  'Missão concluída – seu perfil está pronto para os próximos passos do Music Map.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PPCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seu link público',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Compartilhe no Instagram, WhatsApp ou Linktree.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              SelectableText(
                artistPublicPageUrl(profile.id),
                style: const TextStyle(color: AppColors.primary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: artistPublicPageUrl(profile.id)));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copiado')),
                    );
                  }
                },
                icon: const Icon(Icons.link, size: 18),
                label: const Text('Copiar link'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PPCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ideias premium',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Consultoria de IA para legendas, roteiros e calendário de posts — em breve.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _checkRow(String label, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: done ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: done ? AppColors.textPrimary : AppColors.textSecondary,
                decoration: done ? TextDecoration.none : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mission(BuildContext context, String text, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.task_alt : Icons.circle_outlined,
            size: 18,
            color: done ? AppColors.secondary : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
