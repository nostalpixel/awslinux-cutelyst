# awslinux-cutelyst

Multi-stage Docker image based on **Amazon Linux 2023** with a fully source-built stack.
Supports both Cutelyst v4 and v5.

| Component | v4 image | v5 image |
|-----------|----------|----------|
| Amazon Linux | 2023 | 2023 |
| GCC | 14 (C++23) | 14 (C++23) |
| Qt | 6.8.3 | 6.8.3 |
| Cutelee | 6.2.0 | 6.2.0 |
| Cutelyst | **4.5.0** | **5.0.1** |

## Image layout

| Path | Contents |
|------|----------|
| `/opt/qt6/` | Qt libs, tools (`bin/`, `libexec/`), headers, plugins, mkspecs |
| `/usr/local/lib/` | Cutelee + Cutelyst shared libraries, plugins, cmake configs |
| `/usr/local/include/` | Cutelee + Cutelyst headers |

`CMAKE_PREFIX_PATH` is pre-set to `/opt/qt6:/usr/local`, so `find_package` works without extra flags.

## Tags

| Tag | Cutelyst | Target | Use |
|-----|----------|--------|-----|
| `latest`, `dev`, `v5`, `v5-dev` | 5.0.1 | `dev` | **Build base** — GCC 14, cmake, make, git, openssh, full headers + tools |
| `runtime`, `v5-runtime`, `qt6.8.3-cutelyst5.0.1-runtime` | 5.0.1 | `runtime` | Lean runtime — shared libs + Qt plugins |
| `v4`, `v4-dev`, `qt6.8.3-cutelyst4.5.0-dev` | 4.5.0 | `dev` | v4 build base |
| `v4-runtime`, `qt6.8.3-cutelyst4.5.0-runtime` | 4.5.0 | `runtime` | v4 lean runtime |

## Usage

### Build your Cutelyst app

```dockerfile
FROM ghcr.io/nostalpixel/awslinux-cutelyst:latest AS build

COPY . /src/myapp
RUN cmake -S /src/myapp -B /build/myapp -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
    && cmake --build /build/myapp -j"$(nproc)" \
    && cmake --install /build/myapp --prefix /app

FROM ghcr.io/nostalpixel/awslinux-cutelyst:runtime
COPY --from=build /app /app
CMD ["/app/bin/myapp", "--server"]
```

Use the `v4`/`v4-runtime` tags to target Cutelyst 4.5.0 instead.

## Build arguments

| ARG | Default | Description |
|-----|---------|-------------|
| `QT_VERSION` | `6.8.3` | Qt version to build |
| `QT_PREFIX` | `/opt/qt6` | Qt install prefix |
| `CUTELEE_REF` | `v6.2.0` | Cutelee git tag |
| `CUTELYST_REF` | `v5.0.1` | Cutelyst git tag |

## Build locally

```bash
# runtime image
docker build --target runtime -t cutelyst-runtime .

# dev/build-base image
docker build --target dev -t cutelyst-dev .

# build v4 variant
docker build --target runtime \
  --build-arg CUTELYST_REF=v4.5.0 \
  -t cutelyst-v4-runtime .
```

## Publish

`publish.sh` builds and pushes all tags for both v4 and v5 to `ghcr.io/nostalpixel/awslinux-cutelyst`.

```bash
# authenticate once
docker login ghcr.io   # use a PAT with packages:write

./publish.sh        # build and push both v4 and v5
./publish.sh v4     # v4 only
./publish.sh v5     # v5 only
```
