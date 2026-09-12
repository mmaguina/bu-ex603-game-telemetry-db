players (Actor)
- player_id: INT (PK)
- first_name: VARCHAR
- last_name: VARCHAR
- country: VARCHAR
- dob: DATETIME

matches (Producer)
- match_id: INT (PK)
- name: VARCHAR
- rated: BOOLEAN

game_modes (Catalog)
- mode_id: INT (PK)
- name: VARCHAR
- enabled: BOOLEAN

match_participants (Event & Metric)
- match_id: INT (PK, FK)
- player_id: INT (PK, FK)
- score: INT
- created_at: DATETIME
- game_color: VARCHAR
- elo_result: INT

match_modes (Junction)
- match_id: INT (PK, FK)
- mode_id: INT (PK, FK)

elo_modes (Junction)
- player_id: INT (PK, FK)
- mode_id: INT (PK, FK)
- elo_rating: VARCHAR
