# Unit 2: From Diagram to Database

This document explains the choices made in `/schema/schema.sql`: the order the tables are created in, what happens when a referenced row is deleted, and which bad values the CHECK constraints block.

## Creation order

| # | Table | References | Why it sits here |
|---|-------|------------|------------------|
| 1 | `players` | nothing | Every participation and every rating points back to a player. |
| 2 | `game_modes` | nothing | The list of modes that matches and ratings are sorted by. |
| 3 | `matches` | itself | Its only FK points at itself, so no other table has to exist first. |
| 4 | `match_participants` | `matches`, `players` | Links the two tables above. |
| 5 | `match_modes` | `matches`, `game_modes` | Joins matches and modes, which are many to many. |
| 6 | `elo_modes` | `players`, `game_modes` | Joins players and modes, and holds the rating. |

The reset block drops the tables in the reverse of this order.

## Changes from the Unit 1 design

Building the schema showed some gaps in the Unit 1 ERD. The ERD (`/schema/erd.png`) and its source (`/schema/erd-source.md`) now match the SQL.

1. **Added a recursive foreign key: `matches.rematch_of_match_id`.** The Unit 1 design had no self reference. The reason for putting it here is further down.
2. **`match_participants.score` changed from INT to NUMERIC(2,1).** A chess game scores 1 for a win, 1/2 for a draw and 0 for a loss. An integer column cannot hold 1/2, so every draw would be stored wrong, and win rates with it.
3. **`elo_modes.elo_rating` settled on INTEGER.** The ERD said `int`, but the Unit 1 schema definition said `VARCHAR`. A rating gets compared, averaged and range checked, so it is stored as a number.
4. **`players.dob` changed from DATETIME to DATE.** A birth date has no useful time of day.
5. **`players.country` became CHAR(2), an ISO 3166-1 alpha-2 code.** Free text would let "USA", "U.S." and "United States" all exist, which splits every per country count.
6. **Added `uq_match_participants_color` (UNIQUE on `match_id, game_color`).** Only one player can be white and one can be black in a match.
7. **Added `uq_game_modes_name`.** Two modes both called "Blitz" would split that mode's matches and ratings across two ids.
8. **Fixed the ERD source.** In `matches`, the name and type of the `rated` attribute were the wrong way round (`rated boolean` instead of `boolean rated`).
9. **`game_modes.enabled` is now `NOT NULL DEFAULT TRUE`.** It is how a mode gets retired, so it must always hold a real value.

## Foreign keys and ON DELETE

| Foreign key | ON DELETE | Reason |
|-------------|-----------|--------|
| `matches.rematch_of_match_id` -> `matches` | SET NULL | A rematch is a real game of its own. It has to survive when the game before it is deleted. |
| `match_participants.match_id` -> `matches` | CASCADE | A participation row means nothing without its match, so it goes when the match goes. |
| `match_participants.player_id` -> `players` | RESTRICT | A player's match history is also their opponents' history. It cannot disappear with one account. |
| `match_modes.match_id` -> `matches` | CASCADE | The mode assignment only describes the match. It has no life of its own. |
| `match_modes.mode_id` -> `game_modes` | RESTRICT | A mode that old games were played under has to stay in the list. |
| `elo_modes.player_id` -> `players` | RESTRICT | Ratings are kept as long as the player exists, and the player cannot be deleted while that history exists. |
| `elo_modes.mode_id` -> `game_modes` | RESTRICT | Deleting a mode must not quietly wipe every player's rating in it. |

### When a match is deleted (CASCADE)

On this platform a match is deleted when it is voided. For example, a game that was aborted before the first move because a player lost connection, or a record created by a server fault. The match's participant rows and mode rows go with it in the same statement.

With RESTRICT, voiding a match would take several deletes in order: participants first, then modes, then the match. A cleanup job that failed halfway would leave half deleted games behind.

There is one side effect the schema does not handle. `elo_modes` holds each player's *current* rating, so voiding a rated game that was already scored does not undo those ratings. That has to be done by the application, which works out the affected ratings again. The CASCADE only promises that no orphan rows are left behind.

### When a player is removed (RESTRICT)

A player is removed when an account is closed, often after a ban for cheating. Every match that player played is also a match their opponent played. If deleting a player cascaded, each opponent's history would suddenly hold one sided games, their win rates would change after the fact, and the match record used to work out Elo would have holes in it.

Worse, CASCADE would destroy the evidence at the exact moment a cheater's account is closed, and that history is what an anti cheating audit needs. SET NULL does not work either, because `player_id` is part of the primary key of both `match_participants` and `elo_modes`.

RESTRICT forces account closure to be done as anonymisation instead: overwrite the name, clear `dob` and `country`, and keep the row so the match history stays whole. This replaces the Unit 1 note that suggested CASCADE for GDPR. Anonymisation still meets the right to erasure, and it does not damage other players' data.

### When a game mode is retired (RESTRICT)

Modes change over time. A platform might drop a "Custom" variant or rename a time control. If deleting a mode cascaded, every match played under it would lose its mode. That breaks the ERD rule that every match has at least one mode, and it deletes every player's rating in that mode.

RESTRICT blocks the delete while anything still points at the mode. That leaves one way to retire it: set `enabled = FALSE`. The mode then drops out of the new game menu, while every old game and rating keeps pointing at it.

### When the original of a rematch is deleted (SET NULL)

When the game a rematch followed is voided, only the link is lost. The rematch keeps its own participants, results and ratings.

With CASCADE, voiding one aborted game would delete the rematch after it, then the rematch after that, and so on down the series. Each of those deletes would cascade again into `match_participants` and wipe real results for both players.

With RESTRICT, a game could never be voided once a rematch had been played after it, even when the original really was invalid.

### Placement of the recursive foreign key

The domain gives three options for a self reference:

- a player who referred another player
- a custom game mode based on a standard mode
- a match that is a rematch of an earlier match

The platform has no referral feature, and custom modes are out of scope for now. Rematches, though, are normal behaviour on any online chess site. They also serve one of the stated goals of this database: an accurate match history in date order, for auditing. A long rematch series between the same two accounts, with results that alternate in a suspicious pattern, is a known sign of rating manipulation. With the self reference, that series can be followed with a recursive query.

## CHECK constraints

| Constraint | What it makes impossible to store | How that value could get in |
|------------|-----------------------------------|-----------------------------|
| `chk_players_country_iso` | A country that is not two capital letters, such as `usa`, `Peru` or `us`. | A sign up form that takes free text, or an import from a system that writes countries a different way. Per country statistics would then split one country across several spellings. |
| `chk_players_dob_not_future` | A birth date after today. | A typo in the year (2099 for 1999) or a day and month swapped in a date picker. Any statistic based on age would then be wrong. The check uses `CURRENT_DATE`, which is safe here: a date that is valid today is still valid tomorrow, so old rows can never start failing. |
| `chk_matches_no_self_rematch` | A match stored as a rematch of itself. | A bug that copies a match's own id into `rematch_of_match_id`. A recursive query walking the series would then loop on that row forever. The check uses `IS DISTINCT FROM` instead of `<>` so that NULL, meaning "not a rematch", still passes. |
| `chk_match_participants_color` | A colour other than `white` or `black`. | A client sending `White`, `w` or `1`. A query like "win rate as black" would then quietly miss those games. |
| `chk_match_participants_score` | A score other than 1, 0.5 or 0. | An application that counts points differently, such as 2 for a win in some tournament formats, or a rounding bug. Win rates and Elo both assume the 1, 1/2 and 0 scale. NULL is still allowed, and means the game has not finished. |
| `chk_match_participants_elo_range` | A rating after the game that is outside 0 to 4000. | An overflow or a sign error in the rating maths, for example storing the *change* in rating, such as -12, instead of the new rating. The upper limit is a sanity check for the platform. The highest human classical rating is under 2900. |
| `chk_elo_modes_rating_range` | A current rating outside 0 to 4000. | The same maths bugs as above, but written into the table matchmaking reads. One broken rating would pair that player against opponents far above or below them. |

### Rules the schema cannot enforce with a CHECK

A CHECK constraint only sees one row at a time, so rules that cover several rows or tables are left to the application, or to a trigger added later:

- **Exactly two participants per match.** `uq_match_participants_color` guarantees *at most* two, one per colour, and the primary key stops the same player taking both colours. Neither can guarantee that the second player is there.
- **The two scores add up to 1.** This rule spans two rows.
- **A rated match has an `elo_result` for each player, and an unrated one does not.** This rule spans two tables, `matches.rated` and `match_participants`.
- **Every match has at least one mode.** The ERD shows this (`||--|{`), but DDL can only enforce "zero or more".

## Derived values

Win rates, the most popular mode by hour and similar statistics are worked out at query time from `match_participants`, `match_modes` and `game_modes`. They change with every game, so storing them would mean updating them on every insert. A `GENERATED ... STORED` column is no help here, because it can only read values from its own row.

`elo_modes.elo_rating` is the one derived value the schema does store. It could in theory be rebuilt from the `elo_result` history in date order. In practice matchmaking reads it for every pairing, so it is kept as the player's current state, with `match_participants` as the event history behind it.
