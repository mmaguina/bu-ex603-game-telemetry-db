erDiagram
    players ||--o{ match_participants : "participates in"
    matches ||--o{ match_participants : "includes"
    matches ||--|{ match_modes : "has"
    game_modes ||--o{ match_modes : "assigned to"
    players ||--o{ elo_modes : "has"
    game_modes ||--o{ elo_modes : "is type"

    players {
        int player_id PK
        string first_name
        string last_name
        string country
        datetime dob
    }
    matches {
        int match_id PK
        string name
        rated boolean
    }
    game_modes {
        int mode_id PK
        string name
        boolean enabled
    }
    match_participants {
        int match_id PK, FK
        int player_id PK, FK
        int score
        datetime created_at
        string game_color
        int elo_result
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