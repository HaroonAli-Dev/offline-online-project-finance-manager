import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/async_value_extensions.dart';

import '../../../core/widgets/hint_banner.dart';
import '../data/people_repository.dart';
import '../domain/person_summary.dart';
import '../domain/role_definition.dart';
import 'people_providers.dart';
import 'person_form_dialog.dart';

class PeoplePage extends ConsumerWidget {
  const PeoplePage({super.key});

  static const _wideLayoutBreakpoint = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(peopleProvider);
    final roles = ref.watch(rolesProvider).valueOrNull ?? const [];
    final selectedRole = ref.watch(peopleRoleFilterProvider);
    final includeInactive = ref.watch(peopleIncludeInactiveProvider);
    final repository = ref.read(peopleRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('People'),
        actions: const [PageHelpIconButton(pageKey: 'people')],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: roles.isEmpty
            ? null
            : () => showPersonForm(context, repository, roles),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add person'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;
          final filters = _PeopleFilters(
            roles: roles,
            selectedRole: selectedRole,
            includeInactive: includeInactive,
            onRoleSelected: (roleCode) =>
                ref.read(peopleRoleFilterProvider.notifier).state = roleCode,
            onIncludeInactiveChanged: (value) =>
                ref.read(peopleIncludeInactiveProvider.notifier).state = value,
            onSearchChanged: (value) =>
                ref.read(peopleSearchProvider.notifier).state = value,
            isWide: isWide,
          );
          final list = people.when(
            data: (items) => _PeopleList(
              items: items,
              roles: roles,
              repository: repository,
              isWide: isWide,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Unable to load people: $error')),
          );

          const hint = HintBanner(
            pageKey: 'people',
            hints: [
              'Tap "Add person" (bottom-right) to add an engineer, driver, labourer, or staff member.',
              'Each person can have one or more roles — tick all that apply.',
              'Use the search box to find someone quickly by name.',
              'Use "Filter by role" chips to show only engineers, or only drivers, etc.',
              'Tap the three-dot menu (...) on a card to Edit, Deactivate, or Delete a person.',
              'Use Deactivate (not Delete) when someone leaves — it keeps their history safe.',
              'Turn on "Show inactive" to view deactivated people.',
            ],
          );

          if (isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                hint,
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 280, child: filters),
                      const VerticalDivider(width: 1),
                      Expanded(child: list),
                    ],
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [hint, filters],
                ),
              ),
              Expanded(child: list),
            ],
          );
        },
      ),
    );
  }
}

Future<void> showPersonForm(
  BuildContext context,
  PeopleRepository repository,
  List<RoleDefinition> roles, {
  PersonSummary? person,
}) async {
  final input = await showDialog<PersonInput>(
    context: context,
    builder: (_) => PersonFormDialog(person: person, roles: roles),
  );
  if (input == null || !context.mounted) {
    return;
  }

  try {
    if (person == null) {
      await repository.createPerson(
        fullName: input.fullName,
        roleCodes: input.roleCodes,
        phoneNumber: input.phoneNumber,
        email: input.email,
        address: input.address,
        notes: input.notes,
      );
    } else {
      await repository.updatePerson(
        id: person.id,
        fullName: input.fullName,
        roleCodes: input.roleCodes,
        phoneNumber: input.phoneNumber,
        email: input.email,
        address: input.address,
        notes: input.notes,
        isActive: input.isActive,
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(person == null ? 'Person added.' : 'Person updated.'),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save this person. Please try again.'),
        ),
      );
    }
  }
}

class _PeopleFilters extends StatelessWidget {
  const _PeopleFilters({
    required this.roles,
    required this.selectedRole,
    required this.includeInactive,
    required this.onRoleSelected,
    required this.onIncludeInactiveChanged,
    required this.onSearchChanged,
    required this.isWide,
  });

  final List<RoleDefinition> roles;
  final String? selectedRole;
  final bool includeInactive;
  final ValueChanged<String?> onRoleSelected;
  final ValueChanged<bool> onIncludeInactiveChanged;
  final ValueChanged<String> onSearchChanged;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final roleFilters = [
      FilterChip(
        label: const Text('All roles'),
        selected: selectedRole == null,
        onSelected: (_) => onRoleSelected(null),
      ),
      ...roles.map(
        (role) => FilterChip(
          label: Text(role.displayName),
          selected: selectedRole == role.code,
          onSelected: (_) =>
              onRoleSelected(selectedRole == role.code ? null : role.code),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              labelText: 'Search people',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Filter by role', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: roleFilters,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show inactive'),
            value: includeInactive,
            onChanged: onIncludeInactiveChanged,
          ),
        ],
      ),
    );
  }
}

class _PeopleList extends StatelessWidget {
  const _PeopleList({
    required this.items,
    required this.roles,
    required this.repository,
    required this.isWide,
  });

  final List<PersonSummary> items;
  final List<RoleDefinition> roles;
  final PeopleRepository repository;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyPeopleState();
    }

    final padding = EdgeInsets.fromLTRB(16, 0, 16, isWide ? 24 : 88);
    final listView = ListView.separated(
      padding: padding,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _PersonCard(
        person: items[index],
        onEdit: () =>
            showPersonForm(context, repository, roles, person: items[index]),
        onDelete: () => _confirmDelete(context, repository, items[index]),
        onToggleActive: () => _toggleActive(context, repository, items[index]),
      ),
    );

    if (isWide) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: listView,
        ),
      );
    }

    return listView;
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PeopleRepository repository,
    PersonSummary person,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete person?'),
        content: Text(
          '${person.fullName} will be removed from active records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    await repository.deletePerson(person.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Person deleted.')));
    }
  }

  Future<void> _toggleActive(
    BuildContext context,
    PeopleRepository repository,
    PersonSummary person,
  ) async {
    final makeActive = !person.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(makeActive ? 'Activate person?' : 'Deactivate person?'),
        content: Text(
          makeActive
              ? '${person.fullName} will appear in the active people list again.'
              : '${person.fullName} will be marked inactive but kept in records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(makeActive ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    await repository.setPersonActive(person.id, isActive: makeActive);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            makeActive ? 'Person activated.' : 'Person deactivated.',
          ),
        ),
      );
    }
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final PersonSummary person;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final subtitleLines = <Widget>[
      if (person.phoneNumber != null) Text(person.phoneNumber!),
      if (person.roleNames.isNotEmpty) Text(person.roleNames.join(' · ')),
    ];

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: person.isActive
              ? null
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(person.fullName.substring(0, 1).toUpperCase()),
        ),
        title: Row(
          children: [
            Expanded(child: Text(person.fullName)),
            if (!person.isActive)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Chip(
                  label: Text('Inactive'),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        subtitle: subtitleLines.isEmpty
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: subtitleLines,
              ),
        isThreeLine: subtitleLines.length > 1,
        trailing: PopupMenuButton<_PersonAction>(
          onSelected: (action) => switch (action) {
            _PersonAction.edit => onEdit(),
            _PersonAction.toggleActive => onToggleActive(),
            _PersonAction.delete => onDelete(),
          },
          itemBuilder: (_) {
            final toggleItem = PopupMenuItem<_PersonAction>(
              value: _PersonAction.toggleActive,
              child: Text(person.isActive ? 'Deactivate' : 'Activate'),
            );

            return [
              const PopupMenuItem(
                value: _PersonAction.edit,
                child: Text('Edit'),
              ),
              toggleItem,
              const PopupMenuItem(
                value: _PersonAction.delete,
                child: Text('Delete'),
              ),
            ];
          },
        ),
      ),
    );
  }
}

class _EmptyPeopleState extends StatelessWidget {
  const _EmptyPeopleState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No people found. Add an engineer, driver, labourer, or staff member.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

enum _PersonAction { edit, toggleActive, delete }
