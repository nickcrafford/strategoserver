# Game Server

### Build
```
./scripts/build.sh
```

### Start
```
./scripts/start.sh 9091
```

## Docker

### Build
```
docker build -t nickcrafford/strategoserver .
```

### Run
```
docker run -i -p 9091:9091 nickcrafford/strategoserver
```

## API

### POST /rpc/newGame
- `isPlayer1`
- `playerEmail`
- `opposingEmail`

### POST /rpc/rematch
- `gameId`

### POST /rpc/getMessages
- `gamePlayerId`
- `checksum`

### POST /rpc/setBoard
- `gameId`
- `gamePlayerId`
- `boardPositions` 

### POST /rpc/makeMove
- `gameId`
- `gamePlayerId`
- `sx`
- `sy`
- `tx`
- `ty`
- `checksum`

### POST /rpc/getBoard
- `gameId`
- `gamePlayerId`

## Views

### GET /board/<game_id>/<game_player_id>/

