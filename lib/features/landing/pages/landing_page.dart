import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/page_container.dart';
import '../../../shared/widgets/pp_badge.dart';
import '../../../shared/widgets/pp_button.dart';
import '../../../shared/widgets/pp_card.dart';
import '../../../shared/widgets/pp_logo.dart';

/// Landing — narrativa de **hub operacional** para artistas e bandas (Music Map)
class LandingPage extends ConsumerWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAsync = ref.watch(totalProfileCountProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.landingAura),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHero(context, ref, totalAsync),
              _buildHubPillars(context),
              _buildWhatIs(context),
              _buildBenefits(context),
              _buildCta(context, totalAsync),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, WidgetRef ref, AsyncValue<int> totalAsync) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 64),
      child: PageContainer(
        centered: true,
        maxWidth: 820,
        child: Column(
          children: [
            const PPLogo(showTagline: true, fontSize: 52),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.35)),
              ),
              child: Text(
                'HUB OPERACIONAL PARA ARTISTAS E BANDAS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            totalAsync.when(
              data: (total) => _buildVagasCounter(context, total),
              loading: () => _buildVagasCounter(context, null),
              error: (_, __) => _buildVagasCounter(context, null),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Tudo o que sua carreira precisa, sem trocar de app o tempo todo',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'O ${AppConstants.appName} reúne agenda de shows, checklists de equipamento e estrada, '
              'planejamento de lançamentos e o seu perfil público — tudo no mesmo hub. '
              'Uma conta pode ter vários projetos; você escolhe em qual está trabalhando agora.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.55,
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 400;
                final atLimit = totalAsync.valueOrNull != null && _isAtLimit(totalAsync.valueOrNull);
                return isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PPButton(
                            label: atLimit ? 'Vagas esgotadas' : 'Entrar no acesso antecipado',
                            icon: Icons.person_add_rounded,
                            onPressed: atLimit
                                ? null
                                : () => context.go(
                                      '/register?${AppConstants.referralQueryParam}=${AppConstants.referralLandingValue}',
                                    ),
                            variant: PPButtonVariant.primary,
                            fullWidth: true,
                          ),
                          const SizedBox(height: 12),
                          PPButton(
                            label: 'Já tenho conta',
                            onPressed: () => context.go(
                              '/login?${AppConstants.referralQueryParam}=${AppConstants.referralLandingValue}',
                            ),
                            variant: PPButtonVariant.outline,
                            fullWidth: true,
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PPButton(
                            label: atLimit ? 'Vagas esgotadas' : 'Entrar no acesso antecipado',
                            icon: Icons.person_add_rounded,
                            onPressed: atLimit
                                ? null
                                : () => context.go(
                                      '/register?${AppConstants.referralQueryParam}=${AppConstants.referralLandingValue}',
                                    ),
                            variant: PPButtonVariant.primary,
                            fullWidth: false,
                          ),
                          const SizedBox(width: 16),
                          PPButton(
                            label: 'Já tenho conta',
                            onPressed: () => context.go(
                              '/login?${AppConstants.referralQueryParam}=${AppConstants.referralLandingValue}',
                            ),
                            variant: PPButtonVariant.outline,
                            fullWidth: false,
                          ),
                        ],
                      );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHubPillars(BuildContext context) {
    final pillars = [
      (
        icon: Icons.event_available_rounded,
        title: 'Agenda & shows',
        body: 'Cadastre datas, status e histórico — sua agenda fica clara no hub.',
      ),
      (
        icon: Icons.checklist_rounded,
        title: 'GigBag & checklists',
        body: 'Show, ensaio, viagem ou gravação: listas que acompanham o dia a dia.',
      ),
      (
        icon: Icons.album_rounded,
        title: 'Lançamentos',
        body: 'Planeje singles, EPs e álbuns com marcos para equipe e divulgação.',
      ),
      (
        icon: Icons.public_rounded,
        title: 'Perfil público',
        body: 'Página pública com bio, links e contato — compartilhável em um clique.',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.section, horizontal: 24),
      color: AppColors.surface.withValues(alpha: 0.35),
      child: PageContainer(
        centered: true,
        maxWidth: 1000,
        child: Column(
          children: [
            Text(
              'Um só lugar para correr atrás do show',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Menos planilha solta, grupo de mensagem e calendário genérico. '
              'Mais foco no que importa: sua música e sua operação no mesmo lugar.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final cross = w >= 720 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisExtent: 168,
                  ),
                  itemCount: pillars.length,
                  itemBuilder: (context, i) {
                    final p = pillars[i];
                    return PPCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(p.icon, color: AppColors.primary, size: 28),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            p.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              p.body,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _isAtLimit(int? total) {
    final realCount = total ?? 0;
    final count = AppConstants.earlyAccessReserved + realCount;
    return count >= AppConstants.earlyAccessLimit;
  }

  Widget _buildVagasCounter(BuildContext context, int? total) {
    final realCount = total ?? 0;
    final count = AppConstants.earlyAccessReserved + realCount;
    final limit = AppConstants.earlyAccessLimit;
    final remaining = (limit - count).clamp(0, limit);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Text(
            'Pré-lançamento: $limit vagas no hub (acesso antecipado)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$count',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                ' / $limit',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(width: 12),
              Text(
                '• $remaining restantes',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWhatIs(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: PageContainer(
        centered: true,
        maxWidth: 640,
        child: Column(
          children: [
            Text(
              'O que é o ${AppConstants.appName}?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'É o ${AppConstants.appTagline.toLowerCase()} — um produto para artistas, bandas e quem gerencia carreira '
              'operarem no mesmo lugar: compromissos, pendências, equipamento e lançamentos, '
              'sem ficar pulando entre planilhas e apps soltos.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.55,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefits(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      color: AppColors.surface.withValues(alpha: 0.25),
      child: PageContainer(
        centered: true,
        maxWidth: 880,
        child: Column(
          children: [
            Text(
              'Por que entrar agora?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _benefitCard(
                  context,
                  'Quem entra cedo',
                  'A base inicial do hub recebe novidades e melhorias em primeira mão.',
                ),
                _benefitCard(
                  context,
                  'Roadmap na mesa',
                  'Mentoria com IA, parcerias e network estão no horizonte — você acompanha de dentro.',
                ),
                _benefitCard(
                  context,
                  'Feito para artistas BR',
                  'Linguagem, fluxos e cadastro pensados para bandas e artistas independentes.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _benefitCard(BuildContext context, String title, String text) {
    return SizedBox(
      width: 240,
      child: PPCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PPBadge(label: title, variant: PPBadgeVariant.secondary),
            const SizedBox(height: 12),
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            GestureDetector(
              onTap: () => context.go('/terms'),
              child: Text(
                'Termos de Uso',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
              ),
            ),
            Text('•', style: TextStyle(color: AppColors.textSecondary)),
            GestureDetector(
              onTap: () => context.go('/privacy'),
              child: Text(
                'Política de Privacidade',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCta(BuildContext context, AsyncValue<int> totalAsync) {
    final atLimit = totalAsync.valueOrNull != null && _isAtLimit(totalAsync.valueOrNull);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      child: PageContainer(
        centered: true,
        maxWidth: 520,
        child: Column(
          children: [
            const PPLogo(showTagline: false, fontSize: 40),
            const SizedBox(height: AppSpacing.lg),
            Text(
              atLimit ? 'Vagas esgotadas' : 'Sua banda merece um hub, não só um cadastro',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              atLimit
                  ? 'Acompanhe nossas redes para novas vagas e lançamentos.'
                  : 'Garanta sua vaga no acesso antecipado e organize shows, tarefas e lançamentos hoje.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PPButton(
              label: atLimit ? 'Vagas esgotadas' : 'Quero minha vaga no hub',
              icon: Icons.arrow_forward_rounded,
              onPressed: atLimit
                  ? null
                  : () => context.go(
                        '/register?${AppConstants.referralQueryParam}=${AppConstants.referralLandingValue}',
                      ),
              variant: PPButtonVariant.primary,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
