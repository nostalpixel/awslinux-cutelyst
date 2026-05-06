# awslinux-cutelyst

Multi-stage Docker image based on **Amazon Linux 2023** with a fully source-built stack:

| Component | Version |
|-----------|---------|
| Amazon Linux | 2023 |
| GCC | 14 (C++23) |
| Qt | 6.8.3 |
| Cutelee | 6.2.0 |
| Cutelyst | 5.0.1 |

## Image layout

| Path | Contents |
|------|----------|
| `/opt/qt6/` | Qt libs, tools (`bin/`, `libexec/`), headers, plugins |
| `/usr/local/lib64/` | Cutelee + Cutelyst shared libraries and plugins |
| `/usr/local/lib64/cmake/` | CMake config files for `find_package` |

## Tags

| Tag | Target | Use |
|-----|--------|-----|
| `latest`, `dev` | `dev` | **Build base** — GCC 14, cmake, make, git, openssh, full Qt/Cutelee/Cutelyst headers + tools |
| `runtime`, `qt6.8.3-cutelyst5.0.1-runtime` | `runtime` | **Lean runtime** — only `.so` files + Qt plugins |

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

`CMAKE_PREFIX_PATH` is pre-set to `/opt/qt6:/usr/local` in the image, so no extra cmake flags are needed.

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

# override versions
docker build --target runtime \
  --build-arg QT_VERSION=6.8.3 \
  --build-arg CUTELYST_REF=v5.0.1 \
  -t cutelyst-runtime .
```
