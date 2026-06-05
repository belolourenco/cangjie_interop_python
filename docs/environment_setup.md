# Environment Setup

This project builds a Cangjie Python interop library backed by an embedded
CPython bridge.

## Requirements

- Cangjie toolchain with `cjpm` available.
- `clang`, `ar`, `ranlib`, and `make`.
- Python development headers and embed linker flags available through
  `python3-config`.

Clone and build Cangjie with support for Extern Runtimes from (https://github.com/CJPLUK/cangjie_sdk.git)[https://github.com/CJPLUK/cangjie_sdk.git], branch extern_getPayload_codegen.

```sh
git clone -b extern_getPayload_codegen https://github.com/CJPLUK/cangjie_sdk.git
cd cangjie_sdk
bash ./build_scripts/macos/all.sh
source software/cangjie/envsetup.sh
```

Check Python discovery with:

```sh
python3-config --includes
python3-config --ldflags --embed
```

## Build

From `examples/interop_python`:

```sh
make native
cjpm build
```

`make native` builds `build/native/libpython_bridge.a` from
`native/bridge/python_bridge.c`.

## Test

Run the full suite with:

```sh
make test
```

The test packages link against `libpython_bridge` and the local CPython embed
library. If Python is installed somewhere else, update the `link-option` values
in the test `cjpm.toml` files to match `python3-config --ldflags --embed`.

## Runtime Notes

- CPython is initialized once per process and intentionally not finalized during
  ordinary runtime destruction.
- Every bridge entrypoint acquires the GIL before touching Python objects.
- Returned `Extern<PythonRuntime>` values own strong Python references until the
  Cangjie wrapper is destroyed.
- File-based module imports are cached by absolute path.
