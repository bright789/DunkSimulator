# Server Source

Place server-authoritative services and server-only configuration here. Future gameplay decisions about rewards, progression, purchases, court access, and competitive results belong on the server.

`ServerMain.server.luau` starts `services/PlayerService.luau` (session state and jumps) and `services/TrainingService.luau` (validated trainer interactions). See `docs/VERTICAL_PROTOTYPE.md` for Studio setup and manual tests.

It also starts `BasketballService` (validated pickup and private possession) and `DunkService` (validated dunk requests). Dunk rewards go through PlayerService; see `docs/DUNK_PROTOTYPE.md`.
