-- =====================================================================
-- EX 603 Assignment 2: schema.sql
-- Theme:  Game Telemetry (ChessMatch Analytics Engine)
-- Author: Manuel Maguina Morello
-- Target: PostgreSQL 14+
-- =====================================================================
--
-- Creation order (a table is created only after every table it references):
--   1. players             references nothing
--   2. game_modes          references nothing
--   3. matches             references only itself (rematch_of_match_id)
--   4. match_participants  references matches, players
--   5. match_modes         references matches, game_modes
--   6. elo_modes           references players, game_modes
--
-- =====================================================================

-- Reset. Reverse creation order, so no foreign key blocks a drop.
DROP TABLE IF EXISTS elo_modes          CASCADE;
DROP TABLE IF EXISTS match_modes        CASCADE;
DROP TABLE IF EXISTS match_participants CASCADE;
DROP TABLE IF EXISTS matches            CASCADE;
DROP TABLE IF EXISTS game_modes         CASCADE;
DROP TABLE IF EXISTS players            CASCADE;

-- ----------------------------------------------------------------
-- 1. players (Actor) is first, because it does not reference any other
--    table. Every participation and every rating points here.
-- ----------------------------------------------------------------
CREATE TABLE players (
    player_id   INTEGER      GENERATED ALWAYS AS IDENTITY,
    first_name  VARCHAR(50)  NOT NULL,
    last_name   VARCHAR(50)  NOT NULL,
    country     CHAR(2),                 -- ISO 3166-1 alpha-2, e.g. 'US', 'PE'
    dob         DATE,                    -- date only, time of birth is not needed

    CONSTRAINT pk_players PRIMARY KEY (player_id),

    CONSTRAINT chk_players_country_iso
        CHECK (country ~ '^[A-Z]{2}$'),

    CONSTRAINT chk_players_dob_not_future
        CHECK (dob <= CURRENT_DATE)
);


-- ----------------------------------------------------------------
-- 2. game_modes (Catalog) is second, because it references no other
--    table. It is the list of modes that matches and ratings refer to.
-- ----------------------------------------------------------------
CREATE TABLE game_modes (
    mode_id  INTEGER      GENERATED ALWAYS AS IDENTITY,
    name     VARCHAR(30)  NOT NULL,      -- 'Bullet', 'Blitz', 'Rapid', ...
    enabled  BOOLEAN      NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_game_modes PRIMARY KEY (mode_id),

    CONSTRAINT uq_game_modes_name UNIQUE (name)
);


-- ----------------------------------------------------------------
-- 3. matches (Producer) is third. Its only foreign key points at itself
--    (a rematch references the game it follows), so it needs no other
--    table to exist first. It must exist before any participant or mode
--    assignment can reference it.
-- ----------------------------------------------------------------
CREATE TABLE matches (
    match_id             INTEGER       GENERATED ALWAYS AS IDENTITY,
    name                 VARCHAR(100),
    rated                BOOLEAN       NOT NULL DEFAULT TRUE,
    rematch_of_match_id  INTEGER,        -- NULL = not a rematch

    CONSTRAINT pk_matches PRIMARY KEY (match_id),

    CONSTRAINT fk_matches_rematch_of
        FOREIGN KEY (rematch_of_match_id) REFERENCES matches (match_id)
        ON DELETE SET NULL,

    CONSTRAINT chk_matches_no_self_rematch
        CHECK (rematch_of_match_id IS DISTINCT FROM match_id)
);


-- ----------------------------------------------------------------
-- 4. match_participants (Event & Metric) comes after matches and
--    players, which it links. One row per player per match, the
--    telemetry record written when a game ends.
-- ----------------------------------------------------------------
CREATE TABLE match_participants (
    match_id    INTEGER       NOT NULL,
    player_id   INTEGER       NOT NULL,
    game_color  VARCHAR(5)    NOT NULL,
    score       NUMERIC(2,1),            -- 1 win, 0.5 draw, 0 loss. NULL = not finished
    elo_result  INTEGER,                 -- rating after this game. NULL = unrated or not finished
    created_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_match_participants PRIMARY KEY (match_id, player_id),

    CONSTRAINT uq_match_participants_color UNIQUE (match_id, game_color),

    CONSTRAINT fk_match_participants_match
        FOREIGN KEY (match_id) REFERENCES matches (match_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_match_participants_player
        FOREIGN KEY (player_id) REFERENCES players (player_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_match_participants_color
        CHECK (game_color IN ('white', 'black')),

    CONSTRAINT chk_match_participants_score
        CHECK (score IN (0, 0.5, 1)),

    CONSTRAINT chk_match_participants_elo_range
        CHECK (elo_result BETWEEN 0 AND 4000)
);


-- ----------------------------------------------------------------
-- 5. match_modes (Junction) comes after matches and game_modes, the
--    two sides of the many to many it resolves. The primary key is the
--    pair of foreign keys, not a new id.
-- ----------------------------------------------------------------
CREATE TABLE match_modes (
    match_id  INTEGER  NOT NULL,
    mode_id   INTEGER  NOT NULL,

    CONSTRAINT pk_match_modes PRIMARY KEY (match_id, mode_id),

    CONSTRAINT fk_match_modes_match
        FOREIGN KEY (match_id) REFERENCES matches (match_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_match_modes_mode
        FOREIGN KEY (mode_id) REFERENCES game_modes (mode_id)
        ON DELETE RESTRICT
);


-- ----------------------------------------------------------------
-- 6. elo_modes (Junction with attribute) is last, after players and
--    game_modes. One current rating per player per mode.
-- ----------------------------------------------------------------
CREATE TABLE elo_modes (
    player_id   INTEGER  NOT NULL,
    mode_id     INTEGER  NOT NULL,
    elo_rating  INTEGER  NOT NULL,

    CONSTRAINT pk_elo_modes PRIMARY KEY (player_id, mode_id),

    CONSTRAINT fk_elo_modes_player
        FOREIGN KEY (player_id) REFERENCES players (player_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_elo_modes_mode
        FOREIGN KEY (mode_id) REFERENCES game_modes (mode_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_elo_modes_rating_range
        CHECK (elo_rating BETWEEN 0 AND 4000)
);
