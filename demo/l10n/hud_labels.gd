## Fixture: localization usage for the matrix scanner - one key that
## exists in the table and one that no table answers.
extends Node


## Score line for the HUD. HUD_SCORE is missing from every table on
## purpose, so the scanner reports an untranslated_call.
func score_label(score: int) -> String:
    return tr("HUD_SCORE") + ": " + str(score)


## Start button text - this key exists in demo/l10n/ui.csv.
func start_label() -> String:
    return tr("MENU_START")
