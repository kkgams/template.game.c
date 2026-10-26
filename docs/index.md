---
title: Game development
status: reference
---

# Game development

The game runs on macOS with Metal and in browsers with WebGL2. Both targets
compile the same C game code and shaders. The current scene draws an RGB triangle.

## Run the game and docs

Install Make, Zig 0.17.0, curl and Python 3. Native builds require the Xcode macOS
SDK. Use Node.js 22+ for documentation validation.

Run these commands in separate terminals from the project root:

```sh
make play        # game: http://127.0.0.1:8816
make serve-docs  # docs: http://localhost:8080
```

Use `PORT=…` for the game server and `DOCS_PORT=…` for documentation.
The docs server reloads content as Markdown files change. To run natively,
use `make run` instead of `make play`.

## Change the game

Start in `game/main.c`. Create rendering resources in `init()`, draw in `frame()`,
and release resources in `cleanup()`. The shared lifecycle is declared in
`game/app.h`; platform setup lives in `game/osx/` and `game/web/`.

Edit `game/triangle-sapp.glsl` to change the shader. Rebuilding regenerates its
C header for Metal and WebGL2; do not edit the generated header directly.
Rebuild and reload the browser, or restart the native executable, after changes.

## Check changes

```sh
make validate-docs  # check documentation structure and links
```

Inspect the game in a real browser and on native Metal after rendering changes.
