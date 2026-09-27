erDiagram
    players ||--o{ match_participants : "participates in"
    matches ||--o{ match_participants : "includes"
    matches ||--|{ match_modes : "has"
    game_modes ||--o{ match_modes : "assigned to"
    players ||--o{ elo_modes : "has"
    game_modes ||--o{ elo_modes : "is type"
    matches |o--o{ matches : "rematch of"

    players {
        int player_id PK
        varchar first_name
        varchar last_name
        char country "ISO 3166-1 alpha-2"
        date dob
    }
    matches {
        int match_id PK
        varchar name
        boolean rated
        int rematch_of_match_id FK "self-reference"
    }
    game_modes {
        int mode_id PK
        varchar name UK
        boolean enabled
    }
    match_participants {
        int match_id PK, FK
        int player_id PK, FK
        varchar game_color UK "unique per match"
        numeric score "1 / 0.5 / 0"
        int elo_result
        timestamp created_at
    }
    match_modes {
        int match_id PK, FK
        int mode_id PK, FK
    }
    elo_modes {
        int player_id PK, FK
        int mode_id PK, FK
        int elo_rating
    }
