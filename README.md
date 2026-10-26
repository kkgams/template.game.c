# Game

C game development with Sokol, targeting **macOS/Metal** and **browser WebGL2**.
Both platforms share the same game code and shaders. The current scene draws an
RGB triangle on a black background.

## Run locally

Install Make, Zig 0.17.0, curl and Python 3. Native builds also require macOS and
the Xcode SDK. The shader compiler downloads on first build. No npm dependencies or Emscripten are required.

```sh
make play          # build web and serve http://127.0.0.1:8816
make run           # build and launch the native window
make web           # build build.nosync/web/
make native        # build build.nosync/game
make               # build both targets
```

Set `PORT=…` to change the web server port. Browser controls provide Pause/Resume
and Reload. Reload restarts the application with fresh WASM memory.

## Documentation

Run `make serve-docs` in another terminal alongside the game. Documentation is
served at http://localhost:8080; `DOCS_PORT=…` changes only the docs port.
Edit `docs/index.md` for the development guide. Run `make validate-docs` to check
its structure and links. The pinned wiki engine downloads on first use into
`build.nosync/`; validation requires Node.js 22+.

## Develop

Start in `game/main.c`: `init()` creates rendering resources, `frame()` draws the
scene, and `cleanup()` shuts down Sokol. `game/app.h` declares the shared lifecycle.
Keep game logic shared; platform entrypoints handle graphics setup and swapchains.

| Path | Responsibility |
| --- | --- |
| `game/main.c` | Shared game code and rendering |
| `game/*.glsl` | Authored shaders |
| `game/*.glsl.h` | Generated shader bindings; do not edit manually |
| `game/osx/` | Native entrypoint and Metal implementation |
| `game/web/` | WASM entrypoint, WebGL bridge and browser runner |
| `game/vendor/` | Sokol headers with embedded license notices |

Edit shaders and rebuild normally, or run `make shaders`. The shader compiler
produces Metal and WebGL2 bindings beside each source. Keep both shader sources
and generated headers in version control. Shader include changes trigger
regeneration automatically.

`make deps` downloads missing Sokol headers and shader tools without changing
existing files. To update a dependency, remove its local file, rebuild, and review
the resulting changes. Download sources can be overridden with `SOKOL_URL` and
`SHDC_URL`; upstream versions may introduce incompatible changes.

Build output lives in `build.nosync/`, downloaded tools in `tools/`.
`make clean` removes build output while preserving tools and generated headers.

## Runtime limits

The freestanding web allocator has a 1 MiB heap and does not reclaim allocations;
`realloc` does not preserve existing data. Some GL bridge operations are incomplete.
Check these limits before adding allocations or new rendering features.

## Editor

Open this directory in GAMS to use the Files/Code workspace configured in
`gams.json`. Standalone builds do not require GAMS or its installed Units.

## Publish web

The Pages workflow builds pushes to `release` and pull requests targeting
`release`. Deployment runs only for pushes or manual runs on `release`.
Enable **GitHub Actions** as the Pages source and allow `release` in the
`github-pages` environment.

Only `build.nosync/web/` is deployed. Relative asset URLs support hosting under a
repository subpath. Change `.github/workflows/pages.yml` if using another branch.
