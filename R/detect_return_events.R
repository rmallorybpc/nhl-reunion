# Detect NHL player return events from signing and skater history data.
# Outputs are written to reunion-analysis/.

options(stringsAsFactors = FALSE)

workspace_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
output_dir <- file.path(workspace_root, "reunion-analysis")
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

panel_path <- file.path(workspace_root, "nhl-play-for-contract", "data", "processed", "play_for_contract_analysis_panel.csv")
skaters_path <- file.path(workspace_root, "nhl-play-for-contract", "data", "processed", "nhlscraper_skaters_clean.csv")

if (!file.exists(panel_path)) stop("Missing input file: ", panel_path)
if (!file.exists(skaters_path)) stop("Missing input file: ", skaters_path)

panel <- read.csv(panel_path, check.names = FALSE)
skaters <- read.csv(skaters_path, check.names = FALSE)

required_panel <- c("player_id", "player_name", "signing_year", "signing_team", "previous_team", "retention_status")
required_skaters <- c("player_id", "canonical_name", "season", "team")
missing_panel <- setdiff(required_panel, names(panel))
missing_skaters <- setdiff(required_skaters, names(skaters))
if (length(missing_panel) > 0) stop("Panel is missing columns: ", paste(missing_panel, collapse = ", "))
if (length(missing_skaters) > 0) stop("Skaters is missing columns: ", paste(missing_skaters, collapse = ", "))

clean_code <- function(x) {
  x <- toupper(trimws(as.character(x)))
  x[x %in% c("", "NA", "N/A", "NULL")] <- NA_character_
  x
}

season_start_year <- function(season_value) {
  s <- gsub("[^0-9]", "", as.character(season_value))
  out <- rep(NA_integer_, length(s))
  good <- nchar(s) >= 4
  out[good] <- suppressWarnings(as.integer(substr(s[good], 1, 4)))
  out
}

season_end_year <- function(season_value) {
  s <- gsub("[^0-9]", "", as.character(season_value))
  out <- rep(NA_integer_, length(s))
  good <- nchar(s) >= 8
  out[good] <- suppressWarnings(as.integer(substr(s[good], 5, 8)))
  out
}

panel$signing_team_raw <- clean_code(panel$signing_team)
panel$previous_team_raw <- clean_code(panel$previous_team)
skaters$team_raw <- clean_code(skaters$team)

panel_codes <- sort(unique(na.omit(c(panel$signing_team_raw, panel$previous_team_raw))))
skater_codes <- sort(unique(na.omit(skaters$team_raw)))
all_codes <- sort(unique(c(panel_codes, skater_codes)))

# Explicit team crosswalk with relocation/rebrand continuity handled.
crosswalk <- data.frame(
  source_code = all_codes,
  canonical_team = all_codes,
  mapping_note = rep("identity", length(all_codes)),
  stringsAsFactors = FALSE
)

if ("ATL" %in% crosswalk$source_code) {
  crosswalk$canonical_team[crosswalk$source_code == "ATL"] <- "WPG"
  crosswalk$mapping_note[crosswalk$source_code == "ATL"] <- "Atlanta Thrashers franchise mapped to Winnipeg"
}
if ("WPG" %in% crosswalk$source_code) {
  crosswalk$mapping_note[crosswalk$source_code == "WPG"] <- "Winnipeg Jets (includes former ATL franchise continuity)"
}
for (code in intersect(c("PHX", "ARI", "UTA"), crosswalk$source_code)) {
  crosswalk$canonical_team[crosswalk$source_code == code] <- "UTA"
}
if ("PHX" %in% crosswalk$source_code) {
  crosswalk$mapping_note[crosswalk$source_code == "PHX"] <- "Phoenix Coyotes franchise mapped to Utah"
}
if ("ARI" %in% crosswalk$source_code) {
  crosswalk$mapping_note[crosswalk$source_code == "ARI"] <- "Arizona Coyotes franchise mapped to Utah"
}
if ("UTA" %in% crosswalk$source_code) {
  crosswalk$mapping_note[crosswalk$source_code == "UTA"] <- "Utah franchise (includes former ARI/PHX continuity)"
}

crosswalk <- crosswalk[order(crosswalk$source_code), ]
write.csv(crosswalk, file.path(output_dir, "team_crosswalk.csv"), row.names = FALSE)

map_codes <- function(x, table) {
  m <- setNames(table$canonical_team, table$source_code)
  unname(m[x])
}

panel$signing_team_canonical <- map_codes(panel$signing_team_raw, crosswalk)
panel$previous_team_canonical <- map_codes(panel$previous_team_raw, crosswalk)
skaters$team_canonical <- map_codes(skaters$team_raw, crosswalk)

unmapped_signing <- sort(unique(panel$signing_team_raw[!is.na(panel$signing_team_raw) & is.na(panel$signing_team_canonical)]))
unmapped_skaters <- sort(unique(skaters$team_raw[!is.na(skaters$team_raw) & is.na(skaters$team_canonical)]))

if (length(unmapped_signing) > 0 || length(unmapped_skaters) > 0) {
  msg <- c(
    if (length(unmapped_signing) > 0) paste0("Unmapped signing_team codes: ", paste(unmapped_signing, collapse = ", ")),
    if (length(unmapped_skaters) > 0) paste0("Unmapped skaters team codes: ", paste(unmapped_skaters, collapse = ", "))
  )
  stop(paste(msg, collapse = " | "))
}

skaters$season_start <- season_start_year(skaters$season)
skaters$season_end <- season_end_year(skaters$season)
skaters <- skaters[!is.na(skaters$player_id) & !is.na(skaters$team_canonical) & !is.na(skaters$season_start) & !is.na(skaters$season_end), ]

# Build player stint history by collapsing consecutive same-team seasons.
build_stints <- function(df) {
  if (nrow(df) == 0) {
    return(data.frame(
      player_id = integer(0),
      team = character(0),
      start_season = integer(0),
      end_season = integer(0),
      stringsAsFactors = FALSE
    ))
  }
  df <- df[order(df$player_id, df$season_start, df$season_end, df$team_canonical), ]
  out <- vector("list", 0)

  for (pid in unique(df$player_id)) {
    p <- df[df$player_id == pid, c("player_id", "team_canonical", "season_start", "season_end")]
    p <- p[order(p$season_start, p$season_end), ]
    p <- p[!duplicated(p[, c("player_id", "team_canonical", "season_start", "season_end")]), ]

    cur_team <- p$team_canonical[1]
    cur_start <- p$season_start[1]
    cur_end <- p$season_end[1]

    if (nrow(p) > 1) {
      for (i in 2:nrow(p)) {
        row <- p[i, ]
        is_contiguous <- !is.na(row$season_start) && !is.na(cur_end) && (row$season_start <= (cur_end + 1))
        if (!is.na(row$team_canonical) && row$team_canonical == cur_team && is_contiguous) {
          cur_end <- max(cur_end, row$season_end)
        } else {
          out[[length(out) + 1]] <- data.frame(
            player_id = pid,
            team = cur_team,
            start_season = cur_start,
            end_season = cur_end,
            stringsAsFactors = FALSE
          )
          cur_team <- row$team_canonical
          cur_start <- row$season_start
          cur_end <- row$season_end
        }
      }
    }

    out[[length(out) + 1]] <- data.frame(
      player_id = pid,
      team = cur_team,
      start_season = cur_start,
      end_season = cur_end,
      stringsAsFactors = FALSE
    )
  }

  do.call(rbind, out)
}

stints <- build_stints(skaters)
stints <- stints[order(stints$player_id, stints$start_season, stints$end_season), ]

new_team <- panel[clean_code(panel$retention_status) == "NEW_TEAM", ]
new_team <- new_team[!is.na(new_team$player_id) & !is.na(new_team$signing_year) & !is.na(new_team$signing_team_canonical), ]

classify_signing <- function(pid, signing_team, signing_year, stints_df) {
  ps <- stints_df[stints_df$player_id == pid & stints_df$end_season < signing_year, ]
  if (nrow(ps) == 0) {
    return(list(classification = "pure_new_team", last_left_season = NA_integer_, years_away = NA_integer_, prior_start_season = NA_integer_))
  }

  idx_team <- which(ps$team == signing_team)
  if (length(idx_team) == 0) {
    return(list(classification = "pure_new_team", last_left_season = NA_integer_, years_away = NA_integer_, prior_start_season = NA_integer_))
  }

  qualifying_idx <- integer(0)
  for (idx in idx_team) {
    if (idx < nrow(ps)) {
      after <- ps[(idx + 1):nrow(ps), , drop = FALSE]
      if (any(after$team != signing_team)) {
        qualifying_idx <- c(qualifying_idx, idx)
      }
    }
  }

  if (length(qualifying_idx) == 0) {
    return(list(classification = "pure_new_team", last_left_season = NA_integer_, years_away = NA_integer_, prior_start_season = NA_integer_))
  }

  chosen <- max(qualifying_idx)
  last_left <- ps$end_season[chosen]
  away <- signing_year - last_left

  list(
    classification = "return",
    last_left_season = last_left,
    years_away = away,
    prior_start_season = ps$start_season[chosen]
  )
}

results <- vector("list", nrow(new_team))
for (i in seq_len(nrow(new_team))) {
  r <- new_team[i, ]
  cls <- classify_signing(
    pid = r$player_id,
    signing_team = r$signing_team_canonical,
    signing_year = as.integer(r$signing_year),
    stints_df = stints
  )

  results[[i]] <- data.frame(
    player_id = r$player_id,
    player_name = r$player_name,
    signing_team = r$signing_team_canonical,
    signing_year = as.integer(r$signing_year),
    classification = cls$classification,
    last_left_season = cls$last_left_season,
    years_away = cls$years_away,
    prior_stint_start_season = cls$prior_start_season,
    stringsAsFactors = FALSE
  )
}

classified <- do.call(rbind, results)
return_events <- classified[classified$classification == "return", c("player_id", "player_name", "signing_team", "signing_year", "last_left_season", "years_away")]
return_events <- return_events[order(return_events$signing_year, return_events$signing_team, return_events$player_name), ]

write.csv(return_events, file.path(output_dir, "return_events.csv"), row.names = FALSE)

total_new_team <- nrow(classified)
count_returns <- sum(classified$classification == "return", na.rm = TRUE)
count_pure_new <- sum(classified$classification == "pure_new_team", na.rm = TRUE)

returns_by_year <- aggregate(player_id ~ signing_year, data = classified[classified$classification == "return", ], FUN = length)
names(returns_by_year)[2] <- "return_count"
returns_by_year <- returns_by_year[order(returns_by_year$signing_year), ]

boundary_year <- 2009
return_with_start <- classified[classified$classification == "return", "prior_stint_start_season", drop = TRUE]
fully_visible <- sum(return_with_start > boundary_year, na.rm = TRUE)
possibly_truncated <- sum(return_with_start == boundary_year, na.rm = TRUE)

summary_path <- file.path(output_dir, "return_summary.md")
summary_lines <- c(
  "# NHL Return Events Summary",
  "",
  paste0("- Total new_team signings: ", total_new_team),
  paste0("- Count of returns: ", count_returns),
  paste0("- Count of pure_new_team: ", count_pure_new),
  "",
  "## Returns by signing_year",
  if (nrow(returns_by_year) == 0) "- No return events found." else ""
)

if (nrow(returns_by_year) > 0) {
  for (i in seq_len(nrow(returns_by_year))) {
    summary_lines <- c(summary_lines, paste0("- ", returns_by_year$signing_year[i], ": ", returns_by_year$return_count[i]))
  }
}

summary_lines <- c(
  summary_lines,
  "",
  "## Lookback Visibility Check",
  paste0("- Fully visible returns (prior stint start_season > 2009-2010 boundary): ", fully_visible),
  paste0("- Possibly truncated returns (prior stint start_season = 2009-2010 boundary): ", possibly_truncated)
)

writeLines(summary_lines, summary_path)

cat("Return-event detection complete.\n")
cat("Total new_team signings:", total_new_team, "\n")
cat("Count of returns:", count_returns, "\n")
cat("Count of pure_new_team:", count_pure_new, "\n")
cat("Fully visible returns:", fully_visible, "\n")
cat("Possibly truncated returns:", possibly_truncated, "\n")
cat("Outputs written to:", output_dir, "\n")
