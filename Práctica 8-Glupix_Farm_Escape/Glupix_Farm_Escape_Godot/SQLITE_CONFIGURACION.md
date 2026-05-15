# Configuración SQLite en Godot

Para cumplir el punto de Base de Datos Local de la práctica:

1. Abre Godot.
2. Entra a **AssetLib**.
3. Busca **godot-sqlite**.
4. Instala el plugin.
5. Actívalo en **Project > Project Settings > Plugins**.
6. Ejecuta el juego.

El proyecto usa:

```txt
user://game_data.db
```

Y crea la tabla:

```sql
CREATE TABLE IF NOT EXISTS highscores (
    id INTEGER PRIMARY KEY,
    player_name TEXT DEFAULT 'Jugador',
    max_score INTEGER,
    date TEXT
);
```

El script que controla la base de datos es:

```txt
res://scripts/highscore_manager.gd
```


## Panel de últimos scores

El proyecto consulta la tabla `highscores` para mostrar:

```sql
SELECT id, player_name, max_score, date
FROM highscores
ORDER BY id DESC
LIMIT 10;
```

Y para el máximo histórico:

```sql
SELECT player_name, max_score, date
FROM highscores
ORDER BY max_score DESC, id DESC
LIMIT 1;
```
