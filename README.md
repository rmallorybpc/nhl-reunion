# NHL Reunion

Live site: https://rmallorybpc.github.io/nhl-reunion/

A player-level study of whether NHL players who return to a former organization deliver more than other new-team signings.

## The question

Some NHL free agents sign back with a team they used to play for. The going-in question is whether these returning players deliver more than other players a team signs from elsewhere. A team holds private information about a player it signed before. The test is whether that information shows up as better value on the ice.

## Headline finding

Returning players receive re-signing-grade ice time. Their production does not match it.

Teams give returners more time on ice per cap dollar than they give other new signings. On the scoresheet, returners look like ordinary new signings. Familiarity is priced by the bench. It is not delivered on the ice.

## The numbers

The study compares returning players against all other new-team signings from 2012 through 2025.

- Returns identified: 15 free-agent returns.
- Time on ice: returners run a positive residual where other new signings run negative. The tier-controlled gap is about +1.75 minutes per game (p = 0.02, n = 11 returns with a measurable residual).
- Production: the points change for returners is flat and not distinguishable from other new signings (descriptive only, n = 9).

The time-on-ice result is a signal, not a settled result. It rests on 11 players. Two or three players could move it. Read it as direction, not proof.

## How this fits the prior work

The finding sits against three reference points.

- The [NHL Play for Contract](https://rmallorybpc.github.io/nhl-play-for-contract/) study found same-team re-signings deliver a positive time-on-ice residual (+0.32) and new-team signings a negative one (-0.45). Returners arrive as new signings but land above ordinary re-signings on deployment.
- The [NFL Coach Continuity](https://rmallorybpc.github.io/nfl-coach-continuity/) study found on-field coaching familiarity produced no measurable effect on retained production. This study asks the contractual-familiarity version of that question.
- The management literature on boomerang employees finds no rehire performance premium and flatter growth over time. Two domains, the same shape.

## Scope and limits

- The sample is 15 returns. This is a small-sample, descriptive study. It is framed that way on purpose.
- Returns are detected from free-agent signings only. Trade-backs are excluded because the contract data source does not carry trades. The trigger case for this study, Connor Clifton's 2026 return to Boston, came partly through a trade and is not in the analyzed data.
- The detection window runs from 2012 through 2025. Player stint history is visible from 2009-2010 onward, so a small number of returns whose first stint began before 2009 may be truncated.
- The planned decomposition by whether the general manager or head coach remained was not run. The return count is too small to support it. That decomposition is documented as a future extension if the sample grows.

## Data and sources

This study reuses the data pipeline from the [NHL Play for Contract](https://rmallorybpc.github.io/nhl-play-for-contract/) study. It does not collect new data. The sources below are the ones this study depends on.

- Contracts and signings: community-hosted NHL contract data, [Chief-Zach Sports-Data (salaries)](https://raw.githubusercontent.com/Chief-Zach/Sports-Data/master/NHL/data/salaries/all_players.jsonl).
- Player performance and time on ice: [Chief-Zach Sports-Data (skaters)](https://raw.githubusercontent.com/Chief-Zach/Sports-Data/master/NHL/data/stats/skaters/all_skaters.csv), with the NHL API via the nhlscraper R package used in the source pipeline.
- Time-on-ice residual machinery: reused from the play for contract study, not rebuilt here.

The contract window spans 2012 through 2025. Player stint history is visible from the 2009-2010 season onward.

## Related studies

This is the second entry in the talent reunion series. The studies are analyzed standalone and never pooled.

- [NFL Coach Continuity](https://rmallorybpc.github.io/nfl-coach-continuity/): the first entry. On-field coaching familiarity produced no measurable effect on retained production. This NHL study asks the contractual-familiarity version of that question.
- [NHL Play for Contract](https://rmallorybpc.github.io/nhl-play-for-contract/): the source of the time-on-ice residual method and the same-team and new-team baselines this study compares against.
- [Talent Portability Research](https://rmallorybpc.github.io/talent-portability-research/): the broader portfolio frame on whether performance moves with a player.

## Live site

The findings pages are published from the docs folder in this repository: Overview, Key findings, Methods, and Audit.
