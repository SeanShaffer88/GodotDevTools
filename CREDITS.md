# CREDITS.md

## Author

- **Sean Shaffer** ([SeanShaffer88](https://github.com/SeanShaffer88)): owner and maintainer. The project is licensed under MIT; see [LICENSE](LICENSE).

## Built with

- **Godot Engine** ([godotengine.org](https://godotengine.org)), MIT License, © Juan Linietsky, Ariel Manzur and Godot Engine contributors. Godot is the runtime and editor these addons target. It is not bundled with this repository.
- **GitHub Actions**: `actions/checkout`, `actions/cache` and `actions/upload-artifact` (MIT License, © GitHub, Inc.), used by the CI workflows only.

## Assets

- Every fixture under `demo/` was made for this repository: images, scenes, scripts and data. That includes `demo/shared/icon.svg` and the PNG baselines. They ship under the project's MIT license, and no third-party art, audio or fonts are included.

## AI assistance

- Much of the code, tests and documentation was written with Anthropic's Claude, working to the owner's specifications and dev charter. Every change went through the same headless gate and CI as hand-written work. [AI_USAGE.md](AI_USAGE.md) is the guide for AI agents working in this repo.

## Third-party code

- None. No external GDScript, C# or native libraries are vendored. The optional native accelerator described in [docs/native-accelerator.md](docs/native-accelerator.md) is a design note, and no tool depends on it.
