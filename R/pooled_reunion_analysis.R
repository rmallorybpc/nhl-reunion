#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

root_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)

return_events_path <- file.path(root_dir, "reunion-analysis", "return_events.csv")
panel_path <- file.path(
  root_dir,
  "nhl-play-for-contract",
  "data",
  "processed",
  "play_for_contract_analysis_panel.csv"
)
output_md_path <- file.path(root_dir, "reunion-analysis", "pooled_findings.md")

required_return_cols <- c("player_id", "signing_year", "signing_team")
required_panel_cols <- c(
  "player_id",
  "signing_year",
  "signing_team",
  "retention_status",
  "overpay_residual",
  "post_signing_points_change",
  "tier",
  "model_position_group",
  "age_at_signing"
)

safe_round <- function(x, digits = 4) {
  if (is.na(x)) return(NA_character_)
  format(round(x, digits), nsmall = digits, trim = TRUE)
}

fmt_int <- function(x) {
  if (is.na(x)) return("NA")
  format(as.integer(x), big.mark = ",", scientific = FALSE, trim = TRUE)
}

fmt_num <- function(x, digits = 4) {
  if (is.na(x)) return("NA")
  format(round(as.numeric(x), digits), nsmall = digits, scientific = FALSE, trim = TRUE)
}

make_summary <- function(df, outcome_col) {
  groups <- c("return", "other_new_team")
  out <- data.frame(
    group = groups,
    n_total = NA_integer_,
    n_non_missing = NA_integer_,
    mean = NA_real_,
    median = NA_real_,
    sd = NA_real_,
    stringsAsFactors = FALSE
  )

  for (i in seq_along(groups)) {
    g <- groups[i]
    sub <- df[df$group == g, , drop = FALSE]
    vals <- sub[[outcome_col]]
    out$n_total[i] <- nrow(sub)
    out$n_non_missing[i] <- sum(!is.na(vals))
    out$mean[i] <- if (out$n_non_missing[i] > 0) mean(vals, na.rm = TRUE) else NA_real_
    out$median[i] <- if (out$n_non_missing[i] > 0) median(vals, na.rm = TRUE) else NA_real_
    out$sd[i] <- if (out$n_non_missing[i] > 1) sd(vals, na.rm = TRUE) else NA_real_
  }

  out
}

run_two_sample_tests <- function(df, outcome_col) {
  test_df <- df[!is.na(df[[outcome_col]]), c("group", outcome_col), drop = FALSE]
  return_vals <- test_df[test_df$group == "return", outcome_col]
  other_vals <- test_df[test_df$group == "other_new_team", outcome_col]

  result <- list(
    n_return = length(return_vals),
    n_other = length(other_vals),
    mean_diff_return_minus_other = NA_real_,
    welch_ci_low = NA_real_,
    welch_ci_high = NA_real_,
    welch_p_value = NA_real_,
    wilcoxon_p_value = NA_real_,
    welch_ok = FALSE,
    wilcoxon_ok = FALSE
  )

  if (length(return_vals) > 0 && length(other_vals) > 0) {
    result$mean_diff_return_minus_other <- mean(return_vals) - mean(other_vals)
  }

  if (length(return_vals) >= 2 && length(other_vals) >= 2) {
    wt <- t.test(return_vals, other_vals, var.equal = FALSE, conf.level = 0.95)
    result$welch_ci_low <- unname(wt$conf.int[1])
    result$welch_ci_high <- unname(wt$conf.int[2])
    result$welch_p_value <- unname(wt$p.value)
    result$welch_ok <- TRUE
  }

  if (length(return_vals) >= 1 && length(other_vals) >= 1) {
    wx <- suppressWarnings(wilcox.test(return_vals, other_vals, exact = FALSE, conf.int = FALSE))
    result$wilcoxon_p_value <- unname(wx$p.value)
    result$wilcoxon_ok <- TRUE
  }

  result
}

run_adjusted_model <- function(df, outcome_col) {
  model_df <- df[, c(outcome_col, "group", "tier", "model_position_group", "age_at_signing"), drop = FALSE]
  model_df$return_indicator <- ifelse(model_df$group == "return", 1, 0)
  model_df <- model_df[complete.cases(model_df), , drop = FALSE]

  if (nrow(model_df) < 5 || length(unique(model_df$return_indicator)) < 2) {
    return(list(ok = FALSE, n_model = nrow(model_df)))
  }

  fit <- lm(stats::as.formula(
    paste0(outcome_col, " ~ return_indicator + tier + model_position_group + age_at_signing")
  ), data = model_df)

  sm <- summary(fit)
  coefs <- sm$coefficients

  if (!("return_indicator" %in% rownames(coefs))) {
    return(list(ok = FALSE, n_model = nrow(model_df)))
  }

  ci <- confint(fit, "return_indicator", level = 0.95)

  list(
    ok = TRUE,
    n_model = nrow(model_df),
    beta = unname(coefs["return_indicator", "Estimate"]),
    se = unname(coefs["return_indicator", "Std. Error"]),
    p_value = unname(coefs["return_indicator", "Pr(>|t|)"]),
    ci_low = unname(ci[1]),
    ci_high = unname(ci[2])
  )
}

write_markdown_report <- function(
  output_path,
  raw_return_count,
  distinct_return_count,
  dropped_dupes,
  group_counts,
  summaries,
  tests,
  models,
  descriptive_flags
) {
  lines <- c(
    "# Pooled Reunion Analysis Findings",
    "",
    "## 1) Return Event Deduplication",
    "",
    "| Metric | Value |",
    "|---|---:|",
    paste0("| Raw rows in return_events.csv | ", fmt_int(raw_return_count), " |"),
    paste0("| Distinct return events (player_id + signing_year + signing_team) | ", fmt_int(distinct_return_count), " |"),
    paste0("| Rows dropped as duplicates | ", fmt_int(raw_return_count - distinct_return_count), " |"),
    ""
  )

  if (nrow(dropped_dupes) > 0) {
    lines <- c(lines, "**Dropped duplicate rows:**", "")
    lines <- c(lines, "| player_id | player_name | signing_team | signing_year | last_left_season | years_away |")
    lines <- c(lines, "|---|---|---|---:|---:|---:|")
    for (i in seq_len(nrow(dropped_dupes))) {
      r <- dropped_dupes[i, ]
      pn <- if ("player_name" %in% names(r)) as.character(r$player_name) else "N/A"
      ll <- if ("last_left_season" %in% names(r)) as.character(r$last_left_season) else "N/A"
      ya <- if ("years_away" %in% names(r)) as.character(r$years_away) else "N/A"
      lines <- c(lines, paste0(
        "| ", r$player_id, " | ", pn, " | ", r$signing_team,
        " | ", r$signing_year, " | ", ll, " | ", ya, " |"
      ))
    }
    lines <- c(lines, "")
  }

  lines <- c(
    lines,
    "## 2) Analysis Frame and Group Counts",
    "",
    "**Assertion:** Return rows in analysis frame equals distinct return events — PASSED.",
    paste0("**Clean return n = ", fmt_int(distinct_return_count), "**"),
    "",
    "| Group | Rows |",
    "|---|---:|",
    paste0("| return | ", fmt_int(group_counts["return"]), " |"),
    paste0("| other_new_team | ", fmt_int(group_counts["other_new_team"]), " |"),
    ""
  )

  outcome_names <- c(
    overpay_residual = "overpay_residual (time-on-ice side)",
    post_signing_points_change = "post_signing_points_change (production side)"
  )

  for (outcome_col in names(outcome_names)) {
    outcome_label <- outcome_names[[outcome_col]]
    sum_df <- summaries[[outcome_col]]
    tst <- tests[[outcome_col]]
    mdl <- models[[outcome_col]]

    lines <- c(
      lines,
      paste0("## 3) Outcome Summary: ", outcome_label),
      "",
      "| Group | n total | n non-missing | Mean | Median | SD |",
      "|---|---:|---:|---:|---:|---:|",
      paste0(
        "| return | ",
        fmt_int(sum_df$n_total[sum_df$group == "return"]), " | ",
        fmt_int(sum_df$n_non_missing[sum_df$group == "return"]), " | ",
        fmt_num(sum_df$mean[sum_df$group == "return"]), " | ",
        fmt_num(sum_df$median[sum_df$group == "return"]), " | ",
        fmt_num(sum_df$sd[sum_df$group == "return"]), " |"
      ),
      paste0(
        "| other_new_team | ",
        fmt_int(sum_df$n_total[sum_df$group == "other_new_team"]), " | ",
        fmt_int(sum_df$n_non_missing[sum_df$group == "other_new_team"]), " | ",
        fmt_num(sum_df$mean[sum_df$group == "other_new_team"]), " | ",
        fmt_num(sum_df$median[sum_df$group == "other_new_team"]), " | ",
        fmt_num(sum_df$sd[sum_df$group == "other_new_team"]), " |"
      ),
      ""
    )

    lines <- c(
      lines,
      "## 4) Two-Sample Comparisons",
      "",
      "| Metric | Value |",
      "|---|---:|",
      paste0("| Mean difference (return - other_new_team) | ", fmt_num(tst$mean_diff_return_minus_other), " |"),
      paste0("| Welch 95% CI lower | ", fmt_num(tst$welch_ci_low), " |"),
      paste0("| Welch 95% CI upper | ", fmt_num(tst$welch_ci_high), " |"),
      paste0("| Welch t-test p-value | ", fmt_num(tst$welch_p_value), " |"),
      paste0("| Wilcoxon rank-sum p-value | ", fmt_num(tst$wilcoxon_p_value), " |"),
      ""
    )

    lines <- c(
      lines,
      "## 5) Tier-Controlled Linear Model",
      "",
      "| Metric | Value |",
      "|---|---:|",
      paste0("| Model n (complete cases) | ", fmt_int(mdl$n_model), " |"),
      paste0("| Return coefficient | ", fmt_num(ifelse(isTRUE(mdl$ok), mdl$beta, NA)), " |"),
      paste0("| Return coefficient SE | ", fmt_num(ifelse(isTRUE(mdl$ok), mdl$se, NA)), " |"),
      paste0("| Return coefficient 95% CI lower | ", fmt_num(ifelse(isTRUE(mdl$ok), mdl$ci_low, NA)), " |"),
      paste0("| Return coefficient 95% CI upper | ", fmt_num(ifelse(isTRUE(mdl$ok), mdl$ci_high, NA)), " |"),
      paste0("| Return coefficient p-value | ", fmt_num(ifelse(isTRUE(mdl$ok), mdl$p_value, NA)), " |"),
      ""
    )

    if (isTRUE(descriptive_flags[[outcome_col]])) {
      lines <- c(
        lines,
        "Descriptive-only note: At least one group has fewer than 10 non-missing rows for this outcome, so this estimate is descriptive only and not inferential.",
        ""
      )
    }
  }

  interpretation <- paste(
    "Across both co-primary outcomes, the return group is much smaller than the other_new_team group,",
    "so uncertainty is comparatively large for return estimates.",
    "The tables show raw group summaries, two-sample differences, and tier-controlled model estimates.",
    "These figures quantify direction and magnitude in this sample, but they should be read cautiously and not",
    "as strong evidence on their own where non-missing return observations are limited."
  )

  lines <- c(
    lines,
    "## 6) Plain-Language Reading",
    "",
    interpretation,
    ""
  )

  writeLines(lines, con = output_path, useBytes = TRUE)
}

return_events <- read.csv(return_events_path, check.names = FALSE)
panel <- read.csv(panel_path, check.names = FALSE)

missing_return_cols <- setdiff(required_return_cols, names(return_events))
missing_panel_cols <- setdiff(required_panel_cols, names(panel))

if (length(missing_return_cols) > 0) {
  stop(paste("Missing required columns in return_events.csv:", paste(missing_return_cols, collapse = ", ")))
}
if (length(missing_panel_cols) > 0) {
  stop(paste("Missing required columns in panel file:", paste(missing_panel_cols, collapse = ", ")))
}

# Step 1: Dedupe return events and report raw vs. distinct counts.
raw_return_count <- nrow(return_events)

key_cols <- required_return_cols  # player_id, signing_year, signing_team
distinct_events <- return_events[!duplicated(return_events[, key_cols]), , drop = FALSE]
distinct_return_count <- nrow(distinct_events)

dropped_dupes <- return_events[duplicated(return_events[, key_cols]), , drop = FALSE]
n_dropped <- nrow(dropped_dupes)

cat("=== STEP 1: Return Event Deduplication ===\n")
cat("Raw row count in return_events.csv:", raw_return_count, "\n")
cat("Distinct event count (player_id + signing_year + signing_team):", distinct_return_count, "\n")
cat("Rows dropped as duplicates:", n_dropped, "\n")
if (n_dropped > 0) {
  cat("Dropped duplicate rows:\n")
  print(dropped_dupes)
}

# Step 2: Analysis frame — restrict to new_team rows.
analysis_frame <- panel[panel$retention_status == "new_team", , drop = FALSE]
cat("\n=== STEP 2: Analysis Frame ===\n")
cat("Panel rows with retention_status == 'new_team':", nrow(analysis_frame), "\n")

# Step 3: Tag each frame row; assert return count equals distinct event count.
# One-to-one match: each distinct event tags at most one panel row (first match).
analysis_keys <- paste(analysis_frame$player_id, analysis_frame$signing_year, analysis_frame$signing_team, sep = "||")
return_keys <- paste(distinct_events$player_id, distinct_events$signing_year, distinct_events$signing_team, sep = "||")

analysis_frame$group <- "other_new_team"
for (rk in return_keys) {
  first_idx <- which(analysis_keys == rk)[1]
  if (!is.na(first_idx)) {
    analysis_frame$group[first_idx] <- "return"
  }
}

tagged_return_count <- sum(analysis_frame$group == "return")
cat("\n=== STEP 3: Tagging Assertion ===\n")
cat("Rows tagged as return in analysis frame:", tagged_return_count, "\n")
cat("Distinct return events:", distinct_return_count, "\n")

if (tagged_return_count != distinct_return_count) {
  mismatch_keys <- analysis_keys[analysis_frame$group == "return"]
  cat("MISMATCH DETECTED — stopping.\n")
  cat("Return keys in frame:\n", paste(sort(mismatch_keys), collapse = "\n"), "\n")
  cat("Return event keys:\n", paste(sort(return_keys), collapse = "\n"), "\n")
  stop(sprintf(
    "Assertion failed: tagged return count (%d) != distinct event count (%d).",
    tagged_return_count, distinct_return_count
  ))
}
cat("Assertion passed: return count == distinct event count ==", distinct_return_count, "\n")

group_counts <- table(factor(analysis_frame$group, levels = c("return", "other_new_team")))
cat("\n=== STEP 4: Group Counts ===\n")
cat("return:", as.integer(group_counts["return"]),
    "| other_new_team:", as.integer(group_counts["other_new_team"]), "\n")

outcomes <- c("overpay_residual", "post_signing_points_change")
summaries <- list()
tests <- list()
models <- list()
descriptive_flags <- list()

for (outcome_col in outcomes) {
  summaries[[outcome_col]] <- make_summary(analysis_frame, outcome_col)
  tests[[outcome_col]] <- run_two_sample_tests(analysis_frame, outcome_col)
  models[[outcome_col]] <- run_adjusted_model(analysis_frame, outcome_col)

  n_return_nm <- summaries[[outcome_col]]$n_non_missing[summaries[[outcome_col]]$group == "return"]
  n_other_nm <- summaries[[outcome_col]]$n_non_missing[summaries[[outcome_col]]$group == "other_new_team"]
  descriptive_flags[[outcome_col]] <- (n_return_nm < 10) || (n_other_nm < 10)
}

write_markdown_report(
  output_path = output_md_path,
  raw_return_count = raw_return_count,
  distinct_return_count = distinct_return_count,
  dropped_dupes = dropped_dupes,
  group_counts = group_counts,
  summaries = summaries,
  tests = tests,
  models = models,
  descriptive_flags = descriptive_flags
)

# Step 9 / final console summary.
cat("\n=== FINAL SUMMARY ===\n")
cat("Raw rows in return_events.csv:", raw_return_count, "\n")
cat("Distinct return events (deduped):", distinct_return_count, "\n")
cat("Analysis frame rows (retention_status == 'new_team'):", nrow(analysis_frame), "\n")
cat("Group counts -> return:", as.integer(group_counts["return"]),
    "| other_new_team:", as.integer(group_counts["other_new_team"]), "\n")
cat("Assertion passed: return count ==", distinct_return_count, "\n")

for (outcome_col in outcomes) {
  sum_df <- summaries[[outcome_col]]
  n_return_nm <- sum_df$n_non_missing[sum_df$group == "return"]
  n_other_nm <- sum_df$n_non_missing[sum_df$group == "other_new_team"]
  mdl <- models[[outcome_col]]

  cat("\nOutcome:", outcome_col, "\n")
  cat("Non-missing rows -> return:", n_return_nm, "| other_new_team:", n_other_nm, "\n")

  if (isTRUE(descriptive_flags[[outcome_col]])) {
    cat("Descriptive-only note: At least one group has fewer than 10 non-missing rows;",
        "estimate is descriptive only and not inferential.\n")
  }

  if (isTRUE(mdl$ok)) {
    cat("Return coefficient:", fmt_num(mdl$beta),
        "| SE:", fmt_num(mdl$se),
        "| 95% CI:", paste0("[", fmt_num(mdl$ci_low), ", ", fmt_num(mdl$ci_high), "]"),
        "| p-value:", fmt_num(mdl$p_value),
        "| model n:", fmt_int(mdl$n_model), "\n")
  } else {
    cat("Return coefficient: NA (model could not be estimated with available complete cases).",
        "Model n:", fmt_int(mdl$n_model), "\n")
  }
}

cat("\nWrote findings to:", output_md_path, "\n")
