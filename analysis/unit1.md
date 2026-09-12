# Modelling Justification

The goal of this relational schema prioritizes data integrity, making sure as the platform scales to handle big volume of events, keeping the data consistency across all entities.

For the core entities: players, matches and game_modes, correspondent IDs were created as primary keys. This provides stable, immutable identifiers that remain independent of the business logic and user interface naming conventions. The junction tables: match_participants, match_modes, and elo_modes, use composite primary keys. By defining the primary keys of match_participants as the combination of match_id and player_id, the schema enforces a business rule: a player cannot be recorded in the same match more than once.

I added the elo_modes table to track a player's skill rating for different types of games. Instead of adding a separate column in the players table for every single game mode (like having one column for Blitz and another for Bullet), this table links players directly to the game modes. This design makes it very easy to add new game modes in the future without having to alter the main database tables. Because its primary key combines player_id and mode_id, it naturally guarantees that a player can only have one official Elo rating per game mode.

The foreign key ON DELETE constraints were added to make sure a clear data lifecycle while protecting historical metrics. A CASCADE behavior is applied to the junction references tied to the matches table. When a match is deleted, all of its associated participant records and modes are deleted as well. This prevents orphaned data. The RESTRICT rule was also applied to players and game_modes. Deleting a player or a game mode while historical match data still references them would permanently corrupt the data. RESTRICT forces the system to either retain these records or implement a soft delete feature.

We have also enforced business rules at the schema level rather than relying on the application layer. Enforcing NOT NULL on the created_at timestamp makes sure time data is present for every single participant event.

# Reflection

Another designer could probably take a more denormalize approach for the game modes. Removing the need for game mode table and match mode junction table. And add a column "mode" as a string or enum. The argument for this approach would be having a faster query avoiding additional joins specially when the tables reach high numbers of entries. Also simplies the readabiliy of the data itself.

The normalized approach give a whole entity table for the mode, which allows to hold more abstraction to it. We can add additional requirements per mode, or add some different pricing per each mode, if we had a business logic for this case. It allows us to see how many distinct modes there are, statictical data from the mode point of view. Create new modes, easily, disable old ones. By having an entity we have more control over it, at the cost of heavy joins, but that are other ways to mitigate those costs in the future.