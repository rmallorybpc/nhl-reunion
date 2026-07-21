# Clifton Diagnostic Check

Source files:
- nhl-play-for-contract/data/processed/play_for_contract_analysis_panel.csv
- nhl-play-for-contract/data/processed/nhlscraper_skaters_clean.csv

## 1) Panel rows where player_name contains "Clifton"

| player_id | player_name | signing_year | signing_team | previous_team | contract_type | retention_status | is_extension |
|---|---|---:|---|---|---|---|---|
| 8477365 | Connor Clifton | 2018 | BOS | NA | other | entry | FALSE |
| 8477365 | Connor Clifton | 2019 | BOS | BOS | UFA | same_team | TRUE |
| 8477365 | Connor Clifton | 2023 | BUF | BOS | UFA | new_team | FALSE |

## 2) Connor Clifton rows in nhlscraper_skaters_clean.csv

| player_id | canonical_name | season | team | position | games_played | goals | assists | points |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 8477365 | Connor Clifton | 20182019 | BOS | D | 19 | 0 | 1 | 1 |
| 8477365 | Connor Clifton | 20192020 | BOS | D | 31 | 2 | 0 | 2 |
| 8477365 | Connor Clifton | 20212022 | BOS | D | 60 | 2 | 8 | 10 |
| 8477365 | Connor Clifton | 20222023 | BOS | D | 78 | 5 | 18 | 23 |
| 8477365 | Connor Clifton | 20232024 | BUF | D | 79 | 4 | 14 | 18 |
| 8477365 | Connor Clifton | 20242025 | BUF | D | 60 | 0 | 10 | 10 |

## 3) retention_status distribution

| retention_status | count |
|---|---:|
| entry | 728 |
| new_team | 857 |
| same_team | 1507 |
| unknown | 83 |

## 4) contract_type distribution

| contract_type | count |
|---|---:|
| other | 1223 |
| RFA | 488 |
| UFA | 1464 |

## 5) Crosstab: retention_status x contract_type

| retention_status | other | RFA | UFA |
| --- | --- | --- | --- |
| entry | 263 | 451 | 14 |
| new_team | 171 | 1 | 685 |
| same_team | 717 | 34 | 756 |
| unknown | 72 | 2 | 9 |

## 6) Rows with non-empty previous_team different from signing_team, by retention_status

| retention_status | count |
|---|---:|
| entry | 705 |
| new_team | 857 |
| unknown | 83 |
