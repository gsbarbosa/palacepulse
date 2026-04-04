import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/user_facing_error.dart';
import '../../../shared/models/artist_show.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/widgets/page_container.dart';
import '../../../shared/widgets/pp_card.dart';
import '../../../shared/widgets/pp_error_state.dart';
import '../../../shared/widgets/pp_input.dart';
import '../../../shared/widgets/workspace_page_scaffold.dart';

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _showStatusLabel(String s) {
  switch (s) {
    case ArtistShow.statusConfirmed:
      return 'Confirmado';
    case ArtistShow.statusPending:
      return 'Pendente';
    case ArtistShow.statusCancelled:
      return 'Cancelado';
    default:
      return s;
  }
}

class ShowsPage extends ConsumerWidget {
  final String profileId;

  const ShowsPage({super.key, required this.profileId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Faça login')));
    }
    final profilesAsync = ref.watch(userProfilesProvider(user.uid));
    return profilesAsync.when(
      data: (profiles) {
        UserProfile? profile;
        for (final p in profiles) {
          if (p.id == profileId) {
            profile = p;
            break;
          }
        }
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Agendar shows')),
            body: const Center(child: Text('Perfil não encontrado')),
          );
        }
        return _ShowsScaffold(profile: profile);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Agendar shows')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Agendar shows')),
        body: Center(
          child: PPErrorState(
            debugDetails: e.toString(),
            onRetry: () => ref.invalidate(userProfilesProvider(user.uid)),
          ),
        ),
      ),
    );
  }
}

class _ShowsScaffold extends ConsumerWidget {
  final UserProfile profile;

  const _ShowsScaffold({required this.profile});

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    ArtistShow? existing,
  ) async {
    final svc = ref.read(artistWorkspaceServiceProvider);
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final timeCtrl = TextEditingController(text: existing?.time ?? '');
    final venueCtrl = TextEditingController(text: existing?.venue ?? '');
    final cityCtrl = TextEditingController(text: existing?.city ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    var date = existing?.date ?? DateTime.now();
    var status = existing?.status ?? ArtistShow.statusPending;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing == null ? 'Novo show' : 'Editar show'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PPInput(label: 'Nome do evento', controller: titleCtrl),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data'),
                  subtitle: Text(_formatDate(date)),
                  trailing: const Icon(Icons.calendar_today_rounded),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setSt(() => date = picked);
                  },
                ),
                PPInput(label: 'Horário', controller: timeCtrl, hint: 'Ex.: 21:00'),
                PPInput(label: 'Local', controller: venueCtrl),
                PPInput(label: 'Cidade', controller: cityCtrl),
                PPInput(label: 'Observações', controller: notesCtrl, maxLines: 3),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: ArtistShow.statusLabelsOrder
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text(_showStatusLabel(s))),
                      )
                      .toList(),
                  onChanged: (v) => setSt(() => status = v ?? status),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !context.mounted) return;
    if (titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome do evento')),
      );
      return;
    }

    final show = ArtistShow(
      id: existing?.id ?? '',
      profileId: profile.id,
      title: titleCtrl.text.trim(),
      date: date,
      time: timeCtrl.text.trim(),
      venue: venueCtrl.text.trim(),
      city: cityCtrl.text.trim(),
      notes: notesCtrl.text.trim(),
      status: status,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    try {
      await svc.saveShow(show);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Show salvo')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Não foi possível salvar o show.${userFacingErrorSuffix(e)}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncShows = ref.watch(showsStreamProvider(profile.id));

    return WorkspacePageScaffold(
      title: 'Agenda de shows',
      subtitle: profile.artistName,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo show'),
      ),
      body: PageContainer(
        maxWidth: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Futuros e histórico separados; cancelados ficam registrados.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 24),
            asyncShows.when(
                data: (shows) {
                  if (shows.isEmpty) {
                    return PPCard(
                      child: Text(
                        'Nenhum show ainda. Toque em Novo show para começar.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    );
                  }
                  final upcoming = shows.where((s) => !s.isPast).toList();
                  final past = shows.where((s) => s.isPast).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Futuros',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      if (upcoming.isEmpty)
                        Text(
                          'Sem shows futuros.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        )
                      else
                        ...upcoming.map((s) => _ShowTile(
                              show: s,
                              onEdit: () => _openEditor(context, ref, s),
                              onDelete: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Excluir show?'),
                                    content: const Text('Esta ação não pode ser desfeita.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Excluir'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && context.mounted) {
                                  await ref
                                      .read(artistWorkspaceServiceProvider)
                                      .deleteShow(profile.id, s.id);
                                }
                              },
                            )),
                      const SizedBox(height: 28),
                      Text(
                        'Histórico (passados)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      if (past.isEmpty)
                        Text(
                          'Nenhum show passado.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        )
                      else
                        ...past.map((s) => _ShowTile(
                              show: s,
                              onEdit: () => _openEditor(context, ref, s),
                              onDelete: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Excluir show?'),
                                    content: const Text('Esta ação não pode ser desfeita.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Excluir'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && context.mounted) {
                                  await ref
                                      .read(artistWorkspaceServiceProvider)
                                      .deleteShow(profile.id, s.id);
                                }
                              },
                            )),
                    ],
                  );
                },
                loading: () => const Center(child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    )),
                error: (e, _) => PPErrorState(
                  title: 'Shows indisponíveis',
                  message: 'Não foi possível carregar a lista de shows.',
                  debugDetails: e.toString(),
                  onRetry: () =>
                      ref.invalidate(showsStreamProvider(profile.id)),
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class _ShowTile extends StatelessWidget {
  final ArtistShow show;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ShowTile({
    required this.show,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(show.date);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PPCard(
        onTap: onEdit,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    show.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$dateStr${show.time.isNotEmpty ? ' · ${show.time}' : ''}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (show.venue.isNotEmpty || show.city.isNotEmpty)
              Text(
                [show.venue, show.city].where((x) => x.isNotEmpty).join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(_showStatusLabel(show.status)),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: AppColors.border),
                ),
                if (show.status == ArtistShow.statusCancelled)
                  const Chip(
                    label: Text('Histórico'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
