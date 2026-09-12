match_participants.match_id referencing matches: ON DELETE CASCADE. If a match record is deleted, all participant records tied to that specific match should be automatically removed to prevent orphaned data.

match_participants.player_id referencing players: ON DELETE RESTRICT. Prevent the deletion of a player if they have existing match history, preserving historical game statistics. Alternatively, use ON DELETE CASCADE if GDPR compliance requires hard deletion of user data.

match_modes.match_id referencing matches: ON DELETE CASCADE. If a match is deleted, its junction record mapping it to a game mode should also be destroyed.

match_modes.mode_id referencing game_modes: ON DELETE RESTRICT. You should not be able to delete a global game mode from the catalog if historical matches are still referencing it.

match_participants.created_at: NOT NULL. Makes sure a participation event cannot be recorded without a timestamp.

match_participants.game_color: CHECK (game_color IN ('white', 'black')). Enforces valid chess piece assignments and prevents arbitrary string data.

elo_modes.player_id referencing players: ON DELETE RESTRICT. Prevents player deletion to preserve their historical Elo rating progression.

elo_modes.mode_id referencing game_modes: ON DELETE RESTRICT. Prevents deletion of a game mode if users actively hold Elo ratings in that category.

elo_modes.elo_rating: NOT NULL. Ensures that a player-mode tracking record contains an actual rating value.