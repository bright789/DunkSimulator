# Server Source

Place server-authoritative services and server-only configuration here. Future gameplay decisions about rewards, progression, purchases, court access, and competitive results belong on the server.

`ServerMain.server.luau` starts `PlayerService` for loaded runtime state/jumps, `TrainingService` for validated hold-to-train sessions, and the existing court, challenge, dunk, basketball, and upgrade services. `PlayerService.AwardTraining` applies the validated court multiplier and training cap without using replicated client attributes as authority.

`BasketballService` owns private possession and the same ball's automatic grounded dribble/gather/dunk transitions. Dribble/jump/landing posing and the visible ball are client presentation (`src/client/PresentationController.client.luau`). `DunkService` validates requests and grants only completed-dunk rewards through PlayerService. See `docs/DRIBBLING.md`, `docs/COURT_TRAINING_CAPS.md`, and `docs/DUNK_ANIMATIONS.md`.
