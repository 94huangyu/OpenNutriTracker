import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/data_source/personal_food_data_source.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// User evidence is explicit, editable and distinct from provenance/favorites.
class PersonalFoodActions extends StatefulWidget {
  final MealEntity meal;
  final PersonalFoodDataSource store;
  final ValueChanged<MealEntity> onChanged;
  const PersonalFoodActions({
    super.key,
    required this.meal,
    required this.store,
    required this.onChanged,
  });

  @override
  State<PersonalFoodActions> createState() => _PersonalFoodActionsState();
}

class _PersonalFoodActionsState extends State<PersonalFoodActions> {
  bool _saving = false;

  Future<void> _save(Future<MealEntity> Function() action) async {
    setState(() => _saving = true);
    try {
      final result = await action();
      if (mounted) widget.onChanged(result);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).foodPersonalSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final meal = widget.store.apply(widget.meal);
    if (!meal.canSavePersonalState) return Text(s.foodPersonalIdentityMissing);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              identifier: 'food-favorite',
              child: TextButton.icon(
                style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                onPressed: _saving
                    ? null
                    : () => _save(
                        () => widget.store.setFavorite(meal, !meal.isFavorite),
                      ),
                icon: Icon(
                  meal.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                ),
                label: Text(
                  meal.isFavorite ? s.foodRemoveFavorite : s.foodAddFavorite,
                ),
              ),
            ),
            const Divider(height: 1),
            Semantics(
              identifier: 'food-personal-review',
              child: TextButton.icon(
                style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                onPressed: _saving
                    ? null
                    : () async {
                        final evidence = await showDialog<(String, String)>(
                          context: context,
                          builder: (_) => _ReviewDialog(meal: meal),
                        );
                        if (evidence != null && mounted) {
                          await _save(
                            () => widget.store.review(
                              meal,
                              evidence.$1,
                              evidence.$2,
                            ),
                          );
                        }
                      },
                icon: Icon(
                  meal.isPersonallyReviewed
                      ? Icons.fact_check
                      : Icons.fact_check_outlined,
                ),
                label: Text(
                  meal.isPersonallyReviewed
                      ? s.foodPersonallyReviewed
                      : s.foodPersonalReview,
                ),
              ),
            ),
          ],
        ),
        if (meal.isPersonallyReviewed) ...[
          Text(
            '${_sourceLabel(s, meal.reviewSource!)} · ${DateFormat('yyyy-MM-dd HH:mm').format(meal.reviewedAt!.toLocal())}',
          ),
          Text(meal.reviewNote!),
          Semantics(
            identifier: 'food-clear-review',
            child: TextButton(
              onPressed: _saving
                  ? null
                  : () => _save(() => widget.store.clearReview(meal)),
              child: Text(s.foodClearReview),
            ),
          ),
        ] else
          Text(
            widget.store.reviewIsOutdated(widget.meal)
                ? s.foodDataChangedReview
                : s.foodNotReviewed,
          ),
      ],
    );
  }
}

String _sourceLabel(S s, String source) => switch (source) {
  'package' => s.foodReviewPackage,
  'manufacturer' => s.foodReviewManufacturer,
  'reference' => s.foodReviewReference,
  _ => s.foodReviewOther,
};

class _ReviewDialog extends StatefulWidget {
  final MealEntity meal;
  const _ReviewDialog({required this.meal});
  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _note = TextEditingController(
    text: widget.meal.reviewNote,
  );
  late String _source = widget.meal.reviewSource ?? 'package';
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(s.foodPersonalReview),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.foodReviewExplanation),
              const SizedBox(height: 16),
              Text(s.foodReviewSource),
              const SizedBox(height: 8),
              Semantics(
                identifier: 'food-review-source',
                child: DropdownButtonFormField<String>(
                  initialValue: _source,
                  isExpanded: true,
                  decoration: const InputDecoration(),
                  items: [
                    for (final source in MealEntity.reviewSources)
                      DropdownMenuItem(
                        value: source,
                        child: Text(_sourceLabel(s, source)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) _source = value;
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(s.foodReviewNote),
              const SizedBox(height: 8),
              Semantics(
                identifier: 'food-review-note',
                child: TextFormField(
                  controller: _note,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: s.foodReviewNoteHint,
                    hintMaxLines: 3,
                  ),
                  validator: (value) => value?.trim().isNotEmpty == true
                      ? null
                      : s.foodReviewNoteRequired,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.dialogCancelLabel),
        ),
        TextButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(context, (_source, _note.text));
            }
          },
          child: Text(s.buttonSaveLabel),
        ),
      ],
    );
  }
}
