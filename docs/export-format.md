# Export bundle format

## China fork: full backup v1 (M4, 2026-10-21)

The recording-only fork now opens **My data → Backup and restore**. Full backup
is a versioned ZIP; CSV remains a partial exchange format. The legacy format
below documents older upstream bundles, not the full M4 backup.

The full ZIP contains `manifest.json`, `data.json`, and files beneath
`meal_images/`, `recipe_images/`, and `profile_images/` (including photo-credit
sidecars). Manifest `format` is `ont-full-backup`, `version` is integer `1`,
`createdUtc` is ISO-8601, `entries` enumerates every other ZIP member with byte
length and CRC32, and `counts` enumerates each dataset/suffix row count. CRC32
detects corruption; it is not an authenticity signature. Unknown versions fail
before any data is written.

`data.json` holds `boxes` (each has `name`, `suffix`, and `rows` of `{key,value}`)
and the source `activeProfileId`. DBO values use the existing JSON field names
and units. Integer and string Hive keys remain distinguishable. The explicit
allowlist contains six shared datasets (profiles, app settings, custom foods,
personal food states, recipes and historical activity templates), plus all eight
per-profile datasets (config, diary intakes, historical activities, historical
body details, tracked days, weight history, water and fasting history). Fields
such as original nutrition basis, all 24 nutrients, recipe ingredient snapshots,
favorites and personal-review evidence remain intact. No body/weight/activity
management entry point is enabled by this preservation.

Public food caches, secure-storage encryption keys, API credentials and OS
permissions are excluded. Privacy acceptances and policy-notice acknowledgements
are retained from the receiving device even when backup conflicts win; importing
a file cannot grant privacy consent. The exported ZIP itself is unencrypted,
including private records and photos, as stated before export. Missing referenced
photos, invalid or duplicate identities, incomplete scopes, wrong CRCs, duplicate
ZIP entries, symlinks and unsafe paths are rejected rather than silently omitted.

Restore first validates the whole archive and produces a read-only preview.
It merges records by stable identity, defaulting to **keep local conflicts**;
**use backup conflicts** overwrites matching records/photos only. Records absent
from the backup remain. Diary UUIDs, recipe IDs and source/backend/food IDs avoid
append duplication; storage-key collisions get a new independent row key.
Existing profiles keep their local storage suffix; previously unknown profile
IDs get independent suffixes. The active local profile stays selected. Imported
profiles are accessible through the local profile picker. Daily calorie/macro
summaries are recomputed from the resulting diary using the existing day-label
and hour/minute boundary rules; historical goals are retained.

A changed local dataset/photo after preview invalidates the preview. Before
writes, a detached undo snapshot is persisted to AES-encrypted `RestoreJournal`
and flushed. Dataset writes and photo writes are flushed before the journal is
cleared. A failed operation replays the snapshot. If rollback fails, the journal
remains and the screen blocks further operations until recovery is retried.
On app restart, recovery runs before profile bootstrap or regular data access;
a failed startup recovery opens the existing recovery screen and preserves the
log. This is recoverable cross-store restoration, not a claim that Hive offers
native multi-box transactions or that power-loss/filesystem faults were tested
on every device.

Inputs are bounded to 32 MiB compressed, 64 MiB total expanded, and 10,000 ZIP
members; output growth is checked during inflation as well as against headers.
The implementation keeps detached snapshots/merge plans in memory, so its peak
memory exceeds the file size. Large-database streaming is not implemented.

Old JSON and CSV ZIPs use the same validation/preview/merge/rollback path. Their
three original datasets are required; recipes, weight, activity templates and
personal food states are optional where the old format supports them. Old OFF
micronutrient repairs remain idempotent. Legacy packages describe the currently
selected profile only and show an explicit partial-backup warning; absent
profiles/settings/independent templates/photos are not invented. The retained
legacy `ImportDataUsecase` APIs support old tests/internal callers; the recording
UI no longer exposes their immediate-write dialog.

Platform document-provider write confirmation and actual device process-death
recovery require device evidence. Local ZIP/Hive tests and component captures
are recorded separately in the M4 self-acceptance report.


This document describes the structure of the data export that **Settings →
Export / Import App Data → Export** produces. It exists for the same reason
issue #40 asked for it: people who want to keep their nutrition history in a
plaintext format they can sync via Syncthing, open in a spreadsheet, or feed
into other tooling deserve a stable schema they can read against. Issue #132
asked specifically for CSV export so the import / export round trip would be
symmetric. CSV is a second bundle format rather than an addition to the JSON one.

## Zip layout

The export is a single `.zip` file (default filename
`opennutritracker-export.zip`).

**You pick one format, and the bundle carries only that one.** Settings → Export
offers a JSON / CSV toggle, and the bundle contains either the JSON files or the
CSV files — never both side by side. A tool that unzips expecting a JSON file
next to its CSV counterpart will not find one.

**JSON bundle**

| File                             | Notes                                                    |
| -------------------------------- | -------------------------------------------------------- |
| `user_intake.json`               | Canonical format the app re-imports from.                |
| `user_activity.json`             | Canonical format the app re-imports from.                |
| `user_tracked_day.json`          | Canonical format the app re-imports from.                |
| `user_recipes.json`              | Recipes only. Nested-ingredient shape, no CSV counterpart. |
| `weight_log.json`                | Weight history.                                          |
| `custom_activity_templates.json` | Saved custom activities — name and typical kcal.         |

**CSV bundle**

| File                    | Notes                                                        |
| ----------------------- | ------------------------------------------------------------ |
| `user_intake.csv`       | Same rows as the JSON, with the meal and its nutriments flattened. |
| `user_activity.csv`     | Flat activities.                                             |
| `user_tracked_day.csv`  | Flat tracked days — **lossy, see [Round-trip guarantee](#round-trip-guarantee)**. |

**Photos travel with the JSON bundle only.** User-attached photos are added under
`recipe_images/` and `meal_images/` when you export as JSON, gathered from three places: recipes,
saved custom meals, and **the diary entries themselves**. That third source is not redundant — a
custom meal logged with *Save for next time* off keeps its photo on the entry without leaving a
saved meal behind, so gathering only from the first two put the filename in the JSON and left the
bytes out of the zip ([#1061](https://github.com/simonoppowa/OpenNutriTracker/issues/1061)). A
photo reachable from any of the three is in the bundle exactly once.

A CSV export carries none, and the CSV importer does not restore them — another reason to use
JSON for anything you intend to restore from.

The **profile box** — height, birthday, PAL, goal — is intentionally not
included; see `lib/core/data/data_source/user_data_source.dart`. Note this is the
profile only: your logged **weight history** *is* exported, as `weight_log.json`.

The user can re-import the same zip via **Settings → Import**, in either format.
The CSV files also exist so a spreadsheet, a Syncthing-style backup, or external
tooling can read the same data without going through Hive.

## JSON schema

The JSON files are direct serializations of the Hive DBO classes via
`json_serializable`, so the source of truth lives in
`lib/core/data/dbo/`. The shapes below are summaries — fields may be added in
future versions, and unknown fields are ignored on import.

### `user_intake.json`

Array of intake records:

```jsonc
[
  {
    "id": "uuid-string",
    "unit": "g",                     // or "ml", "serving", ...
    "amount": 120.0,                 // numeric amount in `unit`
    "type": "breakfast",             // breakfast | lunch | dinner | snack
    "dateTime": "2026-05-13T08:15:00.000",
    "meal": {
      "code": "1234567890123",       // barcode or null
      "name": "Whole Milk",
      "brands": "Acme Dairy",
      "thumbnailImageUrl": null,
      "mainImageUrl": null,
      "url": null,
      "mealQuantity": "100",
      "mealUnit": "g",
      "servingQuantity": 250.0,
      "servingUnit": "ml",
      "servingSize": "250 ml",
      "nutritionBasisQuantity": 100.0, // optional fork metadata; see below
      "source": "off",               // unknown | custom | off | fdc | recipe
      "nutriments": {
        "energyKcal100": 61.0,
        "carbohydrates100": 4.8,
        "fat100": 3.3,
        "proteins100": 3.2,
        "sugars100": 5.1,
        "saturatedFat100": 1.9,
        "fiber100": 0.0,
        // Optional extended fields (#237):
        "monounsaturatedFat100": null,
        "polyunsaturatedFat100": null,
        "transFat100": null,
        "cholesterol100": null,
        "sodium100": null,
        "potassium100": null,
        "magnesium100": null,
        "calcium100": null,
        "iron100": null,
        "zinc100": null,
        "phosphorus100": null,
        "vitaminA100": null,
        "vitaminC100": null,
        "vitaminD100": null,
        "vitaminB6100": null,
        "vitaminB12100": null,
        "niacin100": null
      },
      "dataVersion": 1                // see "Micronutrient units" below
    }
  }
]
```

#### Micronutrient units on Open Food Facts rows

The `*100` micronutrient fields are stored in the app's units: milligrams
for cholesterol, the minerals and vitamins C, B6 and niacin, micrograms for
vitamins A, D and B12. Builds up to 2.3.0 wrote Open Food Facts rows with
those fields in the raw grams the API sends — a thousand times too small for
the milligram fields, a million for the microgram ones
([#775](https://github.com/simonoppowa/OpenNutriTracker/pull/775)).

`dataVersion` on the meal (and the `meal_data_version` column in the CSV) is
how the importer tells the two apart
([#1152](https://github.com/simonoppowa/OpenNutriTracker/issues/1152)): a
row whose `source` is `off` and whose version is absent or below `1` is
scaled into app units on import; a row at `1` or above is taken as-is. Rows
from every other source are never scaled. Tooling that writes `off` rows in
app units should set the version to `1`, or the importer will scale them a
second time. The same repair runs once over the on-device data on the first
launch after the upgrade — the diary, the Open Food Facts cache, the saved
custom meals and the recipe library. Saved custom meals are not part of the
bundle, so they are repaired on the device only (the app itself never saves
an `off` product for reuse, so that box is covered for completeness rather
than for a known row).

### `user_activity.json`

Array of logged physical-activity records:

```jsonc
[
  {
    "id": "uuid-string",
    "duration": 45.0,                // minutes
    "burnedKcal": 320.0,
    "date": "2026-05-13T18:00:00.000",
    "physicalActivityDBO": {
      "code": "01010",               // 2024 Adult Compendium code
      "specificActivity": "Running, 8 km/h",
      "description": "Running, 8 km/h (7.5 min/km)",
      "mets": 8.3,
      "tags": ["cardio", "outdoor"],
      "type": "running"              // bicycling | conditioningExercise | dancing | running | sport | waterActivities | winterActivities
    }
  }
]
```

Records also carry the optional `userKcal` (set once the user edits an
activity's calories, `null` before that), plus `externalId` (the health-store
record an imported workout came from, which is what stops a re-import
duplicating it) and `sourceReportedKcal` (the energy the device reported before
the workout calorie credit); the latter two are `null` on manually logged
activities, and all three round-trip on import/export.

### `user_tracked_day.json`

Array of per-day calorie/macro totals:

```jsonc
[
  {
    "day": "2026-05-13T00:00:00.000",
    "calorieGoal": 2200.0,
    "caloriesTracked": 1850.0,
    "carbsGoal": 330.0,
    "carbsTracked": 270.0,
    "fatGoal": 61.0,
    "fatTracked": 55.0,
    "proteinGoal": 110.0,
    "proteinTracked": 95.0
  }
]
```

### Original label basis (China fork)

`meal.nutritionBasisQuantity` optionally remembers the g/mL basis entered on a
food label, independently of package size and serving size. For example, a
60 g package with a 15 g serving and an 80 kcal / 15 g label keeps `15` here,
while `energyKcal100` remains `80 * 100 / 15`. Intake calculations continue to
use the canonical per-100 values. Missing, non-finite or non-positive metadata
is displayed with a basis of 100; no existing nutrient value is rewritten.

This metadata is serialized wherever an existing MealDBO is serialized; it does
not add saved custom-food templates to the export bundle. The existing backup
coverage limitations below still apply.

### `user_recipes.json`

Array of recipe records, each holding an `ingredients` list referencing
external food items by code. The nested-ingredient shape makes CSV a poor fit
here, so recipes ship as JSON only. See `lib/core/data/dbo/recipe_dbo.dart`
for the precise field list.

## CSV schema

All CSV files use UTF-8, comma as the field separator, `\n` as the line
terminator, and the same minimal quoting rules as the existing CSV importer
(`lib/core/utils/csv_row_parser.dart`):

- A cell is wrapped in double quotes when it contains `,`, `"`, `\n`, or `\r`.
- Embedded double quotes inside a quoted cell are escaped by doubling: `""`.
- Empty cells represent `null` for nullable columns.
- Numeric cells accept `.` or `,` as the decimal mark; the exporter always
  writes `.`.
- Date/time cells are ISO-8601 strings (`DateTime.toIso8601String()`).

Column **order** in the exported CSV matches the table below, but the parser
is **header-driven**, so external tooling can re-order columns freely.
Header lookup is case-insensitive.

### `user_intake.csv`

| Column                          | Type   | Required | Notes                                          |
| ------------------------------- | ------ | -------- | ---------------------------------------------- |
| `id`                            | string | yes      | Intake UUID.                                   |
| `date_time`                     | string | yes      | ISO-8601 timestamp.                            |
| `type`                          | enum   | yes      | `breakfast` / `lunch` / `dinner` / `snack`.    |
| `amount`                        | number | yes      | Quantity logged.                               |
| `unit`                          | string | yes      | e.g. `g`, `ml`, `serving`.                     |
| `meal_code`                     | string | no       | Barcode / FDC ID; empty for custom foods.      |
| `meal_name`                     | string | no       |                                                |
| `meal_brands`                   | string | no       |                                                |
| `meal_source`                   | enum   | no       | `unknown` / `custom` / `off` / `fdc` / `recipe`. |
| `meal_quantity`                 | string | no       | e.g. `100`.                                    |
| `meal_unit`                     | string | no       | e.g. `g`.                                      |
| `meal_serving_quantity`         | number | no       |                                                |
| `meal_serving_unit`             | string | no       |                                                |
| `meal_serving_size`             | string | no       | Human-readable size.                           |
| `meal_thumbnail_url`            | string | no       |                                                |
| `meal_main_image_url`           | string | no       |                                                |
| `meal_url`                      | string | no       |                                                |
| `kcal_per_100g`                 | number | no       | All `*_per_100g` columns are nutriment values per 100 g of the food, not per logged portion. |
| `carbs_per_100g`                | number | no       |                                                |
| `fat_per_100g`                  | number | no       |                                                |
| `protein_per_100g`              | number | no       |                                                |
| `sugars_per_100g`               | number | no       |                                                |
| `saturated_fat_per_100g`        | number | no       |                                                |
| `fiber_per_100g`                | number | no       |                                                |
| `monounsaturated_fat_per_100g`  | number | no       | Extended lipid profile (#237).                 |
| `polyunsaturated_fat_per_100g`  | number | no       |                                                |
| `trans_fat_per_100g`            | number | no       |                                                |
| `cholesterol_per_100g`          | number | no       | mg.                                            |
| `sodium_per_100g`               | number | no       | mg.                                            |
| `potassium_per_100g`            | number | no       | mg.                                            |
| `magnesium_per_100g`            | number | no       | mg.                                            |
| `calcium_per_100g`              | number | no       | mg.                                            |
| `iron_per_100g`                 | number | no       | mg.                                            |
| `zinc_per_100g`                 | number | no       | mg.                                            |
| `phosphorus_per_100g`           | number | no       | mg.                                            |
| `vitamin_a_per_100g`            | number | no       | µg RAE.                                        |
| `vitamin_c_per_100g`            | number | no       | mg.                                            |
| `vitamin_d_per_100g`            | number | no       | µg.                                            |
| `vitamin_b6_per_100g`           | number | no       | mg.                                            |
| `vitamin_b12_per_100g`          | number | no       | µg.                                            |
| `niacin_per_100g`               | number | no       | mg (B3).                                       |
| `meal_data_version`             | number | no       | Micronutrient unit stamp; missing means legacy. |
| `meal_nutrition_basis_quantity` | number | no       | Original label basis in g/mL; absent displays as 100. |
| `meal_original_source`         | string | no       | Original public source code (e.g. `off`, `bls`) retained by a personal correction; absent is unknown. |
| `meal_original_code`           | string | no       | Original public item identifier; independent of a later edited barcode. |

### `user_activity.csv`

| Column              | Type   | Required | Notes                                                                  |
| ------------------- | ------ | -------- | ---------------------------------------------------------------------- |
| `id`                | string | yes      | UUID.                                                                  |
| `date`              | string | yes      | ISO-8601 timestamp.                                                    |
| `duration`          | number | yes      | Minutes.                                                               |
| `burned_kcal`       | number | yes      |                                                                        |
| `activity_code`     | string | yes      | 2024 Adult Compendium code.                                            |
| `specific_activity` | string | yes      | Human-readable activity name.                                          |
| `description`       | string | yes      |                                                                        |
| `mets`              | number | yes      | MET value.                                                             |
| `tags`              | string | no       | Pipe-separated (`outdoor|cardio`) so the cell stays single-field.      |
| `type`              | enum   | yes      | `bicycling` / `conditioningExercise` / `dancing` / `running` / `sport` / `waterActivities` / `winterActivities`. |
| `user_kcal`            | number | no       | Set when the kcal figure is the user's own or a device's rather than the MET formula's. |
| `external_id`          | string | no       | Health Connect / Apple Health record id for an imported workout; empty for a manually logged one. |
| `source_reported_kcal` | number | no       | What the device reported for an imported workout, before the calorie-credit multiplier. |

### `user_tracked_day.csv`

| Column              | Type   | Required | Notes                                |
| ------------------- | ------ | -------- | ------------------------------------ |
| `day`               | string | yes      | ISO-8601 date (start of day).        |
| `calorie_goal`      | number | yes      |                                      |
| `calories_tracked`  | number | yes      |                                      |
| `carbs_goal`        | number | no       | g.                                   |
| `carbs_tracked`     | number | no       | g.                                   |
| `fat_goal`          | number | no       | g.                                   |
| `fat_tracked`       | number | no       | g.                                   |
| `protein_goal`      | number | no       | g.                                   |
| `protein_tracked`   | number | no       | g.                                   |

## Round-trip guarantee

Intakes and activities round-trip cleanly through
`lib/core/utils/csv_data_exporter.dart` — exporting a list of DBOs and parsing
the resulting CSV yields structurally equal DBOs (modulo
empty-string-vs-null normalisation on nullable fields). The unit test
`test/unit_test/csv_data_exporter_test.dart` pins this behaviour.

**Tracked days do not round-trip.** `trackedDayColumns` carries nine columns
while `TrackedDayDBO` has nineteen fields: the ten per-nutrient goals — fibre,
saturated fat, sugars, sodium, calcium, iron, potassium, magnesium, vitamin B12
and vitamin D — have no column and are lost on a CSV export. The JSON bundle
keeps them. Use JSON if you intend to restore from the bundle rather than read
it in a spreadsheet.

**CSV import works.** `ImportDataUsecase.importDataCsv` reads `user_intake.csv`,
`user_activity.csv` and `user_tracked_day.csv`, and Settings → Import uses the
same format toggle as the export. External tooling can therefore write either
shape — subject to the tracked-day loss above.

## Syncthing-friendly notes

The export is deliberately plain UTF-8 inside a normal zip — no binary
encoding, no app-specific framing — so it is safe to leave a copy in a
Syncthing folder and let the same bundle move between devices. The JSON
files re-import losslessly; the CSV files are stable across versions
(columns can be added at the end, never reordered or removed without a
schema bump).

### China fork M3: personal food choices

Meal objects append optional `isFavorite` (boolean), `reviewSource` (`package`,
`manufacturer`, `reference`, `other`), `reviewNote` (string) and `reviewedAt`
(ISO 8601 UTC; new checks use millisecond precision). Missing fields mean no
favorite and no personal check. A personal check requires all three evidence
fields; a source database, custom origin, translation flag or favorite alone
never supplies one. Existing intake and ingredient snapshots keep their saved
values and evidence; editing a template does not rewrite them.

JSON archives append optional `personal_foods.json`, an array of complete meal
objects from the encrypted personal library. This includes saved public foods
that have never been logged. CSV archives append `personal_foods.csv`, using the
meal columns of the intake CSV, without its first five intake-only columns.
Intake CSV appends favorite/evidence plus backend source, local photo path,
full-record and translated-name flags; missing columns remain compatible.
Quoted commas, escaped quotes and multiline evidence are supported. JSON also
includes photos referenced only by this personal library. CSV keeps paths,
without photo bytes, as before.

Old archives without either optional file are still accepted. New personal-food
records validate identity and complete evidence before writing their batch.
This extension does not fix the older full-archive coverage, cross-dataset
atomicity or repeated intake-import issues; those remain M4 work. A backup is
local plaintext once exported, like the existing JSON/CSV archive.
