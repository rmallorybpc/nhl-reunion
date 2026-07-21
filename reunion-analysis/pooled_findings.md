# Pooled Reunion Analysis Findings

## 1) Distinct Return Events

| Metric | Value |
|---|---:|
| Distinct return events (player_id + signing_year + signing_team) | 15 |

## 2) Analysis Frame and Group Counts

| Group | Rows |
|---|---:|
| return | 16 |
| other_new_team | 841 |
| Return count equals distinct return events? | No |

## 3) Outcome Summary: overpay_residual (time-on-ice side)

| Group | n total | n non-missing | Mean | Median | SD |
|---|---:|---:|---:|---:|---:|
| return | 16 | 11 | 0.8436 | 1.5621 | 2.0119 |
| other_new_team | 841 | 581 | -0.4772 | -0.4291 | 2.3454 |

## 4) Two-Sample Comparisons

| Metric | Value |
|---|---:|
| Mean difference (return - other_new_team) | 1.3207 |
| Welch 95% CI lower | -0.0390 |
| Welch 95% CI upper | 2.6805 |
| Welch t-test p-value | 0.0558 |
| Wilcoxon rank-sum p-value | 0.0522 |

## 5) Tier-Controlled Linear Model

| Metric | Value |
|---|---:|
| Model n (complete cases) | 454 |
| Return coefficient | 1.7470 |
| Return coefficient SE | 0.7463 |
| Return coefficient 95% CI lower | 0.2804 |
| Return coefficient 95% CI upper | 3.2137 |
| Return coefficient p-value | 0.0197 |

## 3) Outcome Summary: post_signing_points_change (production side)

| Group | n total | n non-missing | Mean | Median | SD |
|---|---:|---:|---:|---:|---:|
| return | 16 | 9 | 0.0517 | 0.0575 | 0.1202 |
| other_new_team | 841 | 473 | -0.0056 | -0.0083 | 0.1642 |

## 4) Two-Sample Comparisons

| Metric | Value |
|---|---:|
| Mean difference (return - other_new_team) | 0.0573 |
| Welch 95% CI lower | -0.0356 |
| Welch 95% CI upper | 0.1502 |
| Welch t-test p-value | 0.1952 |
| Wilcoxon rank-sum p-value | 0.2289 |

## 5) Tier-Controlled Linear Model

| Metric | Value |
|---|---:|
| Model n (complete cases) | 482 |
| Return coefficient | 0.0783 |
| Return coefficient SE | 0.0539 |
| Return coefficient 95% CI lower | -0.0276 |
| Return coefficient 95% CI upper | 0.1843 |
| Return coefficient p-value | 0.1469 |

Descriptive-only note: At least one group has fewer than 10 non-missing rows for this outcome, so this estimate is descriptive only and not inferential.

## 6) Plain-Language Reading

Across both co-primary outcomes, the return group is much smaller than the other_new_team group, so uncertainty is comparatively large for return estimates. The tables show raw group summaries, two-sample differences, and tier-controlled model estimates. These figures quantify direction and magnitude in this sample, but they should be read cautiously and not as strong evidence on their own where non-missing return observations are limited.

