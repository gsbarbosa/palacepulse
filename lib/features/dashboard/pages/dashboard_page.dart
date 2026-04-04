import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/dashboard_modules.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/widgets/page_container.dart';
import '../../../shared/widgets/pp_button.dart';
import '../../../shared/widgets/pp_error_state.dart';
import '../widgets/dashboard_operation_panel.dart';
import '../widgets/feature_hub_card.dart';

/// Central do hub — operação ligada ao projeto ativo no shell
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  void _syncWorkspaceProfile(WidgetRef ref, List<UserProfile> profiles) {
    final selected = ref.read(dashboardWorkspaceProfileIdProvider);
    final valid = selected != null && profiles.any((p) => p.id == selected);
    final resolved = !valid
        ? profiles.first.id
        : profiles.firstWhere((p) => p.id == selected).id;
    if (!valid) {
      Future.microtask(() {
        ref.read(dashboardWorkspaceProfileIdProvider.notifier).state = resolved;
      });
    }
  }

  String _resolveProfileId(WidgetRef ref, List<UserProfile> profiles) {
    final selected = ref.watch(dashboardWorkspaceProfileIdProvider);
    if (selected != null && profiles.any((p) => p.id == selected)) {
      return selected;
    }
    return profiles.first.id;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profilesAsync = user != null ? ref.watch(userProfilesProvider(user.uid)) : null;

    return profilesAsync?.when(
      data: (profiles) {
        if (profiles.isEmpty) {
          return Scaffold(
            body: Center(
              child: PageContainer(
                maxWidth: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Complete seu perfil no hub',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Crie seu primeiro perfil artístico para liberar a central, shows, '
                      'tarefas, GigBag e lançamentos — tudo no mesmo hub.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PPButton(
                      label: 'Começar agora',
                      icon: Icons.rocket_launch_rounded,
                      onPressed: () => context.push('/complete-profile'),
                      variant: PPButtonVariant.primary,
                      fullWidth: true,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        _syncWorkspaceProfile(ref, profiles);
        final profileId = _resolveProfileId(ref, profiles);
        final active = profiles.firstWhere((p) => p.id == profileId);
        final displayName = user?.displayName;
        final email = user?.email;
        final greetName = (displayName != null && displayName.trim().isNotEmpty)
            ? displayName.trim()
            : (email ?? 'artista');

        return Scaffold(
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroSection(greetName: greetName, projectName: active.artistName),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: PageContainer(
                    maxWidth: AppSpacing.maxContent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.lg),
                        _QuickActions(profileId: profileId),
                        const SizedBox(height: AppSpacing.xl),
                        DashboardOperationPanel(profile: active),
                        const SizedBox(height: AppSpacing.xxl),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Sua operação no hub',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Cada área abaixo usa o projeto ativo que você escolheu na barra superior. '
                          'Assim você não mistura agenda de uma banda com lançamentos de outra.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            final cross = w >= 720 ? 2 : 1;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cross,
                                mainAxisSpacing: AppSpacing.md,
                                crossAxisSpacing: AppSpacing.md,
                                mainAxisExtent: 200,
                              ),
                              itemCount: DashboardModuleConfig.all.length,
                              itemBuilder: (context, i) {
                                final m = DashboardModuleConfig.all[i];
                                final enabled = m.status == DashboardModuleStatus.enabled;
                                return FeatureHubCard(
                                  title: m.title,
                                  description: m.description,
                                  icon: m.icon,
                                  comingSoon: !enabled,
                                  onTap: enabled
                                      ? () => context.push('${m.routePattern}/$profileId')
                                      : null,
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: user != null
              ? PPErrorState(
                  debugDetails: e.toString(),
                  onRetry: () {
                    ref.invalidate(userProfilesProvider(user.uid));
                  },
                )
              : PPErrorState(debugDetails: e.toString()),
        ),
      ),
    ) ??
        const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.greetName,
    required this.projectName,
  });

  final String greetName;
  final String projectName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: AppGradients.subtleGlow,
      ),
      child: PageContainer(
        maxWidth: AppSpacing.maxContent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Olá, $greetName',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text.rich(
              TextSpan(
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                children: [
                  const TextSpan(
                    text:
                        'Esta é sua central no ${AppConstants.appName}: um hub para agenda, checklists, '
                        'lançamentos e perfil público — ',
                  ),
                  TextSpan(
                    text: projectName,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: ' é o projeto em foco agora.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, IconData icon, VoidCallback onTap})>[
      (
        label: 'Shows',
        icon: Icons.event_rounded,
        onTap: () => context.push('/shows/$profileId'),
      ),
      (
        label: 'Tarefas',
        icon: Icons.task_alt_rounded,
        onTap: () => context.push('/tasks/$profileId'),
      ),
      (
        label: 'GigBag',
        icon: Icons.checklist_rounded,
        onTap: () => context.push('/gigbag/$profileId'),
      ),
      (
        label: 'Lançamentos',
        icon: Icons.album_rounded,
        onTap: () => context.push('/releases/$profileId'),
      ),
      (
        label: 'Meu espaço',
        icon: Icons.person_rounded,
        onTap: () => context.push('/perfil'),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items) ...[
            _ActionChip(
              label: item.label,
              icon: item.icon,
              onTap: item.onTap,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
