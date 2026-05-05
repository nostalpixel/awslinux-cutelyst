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
| `/opt/qt6/` | Qt shared libraries + plugins |
| `/usr/local/lib64/` | Cutelee + Cutelyst shared libraries and plugins |
| `/usr/local/lib64/cmake/` | CMake config files for find_package |

## Targets

| Target | Use |
|--------|-----|
| `runtime` | Minimal runtime image — only `.so` files, no headers or build tools |
| `dev` | Full build-base — Qt/Cutelee/Cutelyst headers, cmake configs, GCC 14, ninja |
| `qt-builder` | Intermediate: Qt 6 built from source |

## Usage

### Pull from GHCR

```bash
# runtime
docker pull ghcr.io/nostalpixel/awslinux-cutelyst:latest

# pinned version
docker pull ghcr.io/nostalpixel/awslinux-cutelyst:qt6.8.3-cutelyst5.0.1
```

### Build your Cutelyst app

```dockerfile
FROM ghcr.io/nostalpixel/awslinux-cutelyst:latest AS dev

COPY . /src/myapp
RUN cmake -S /src/myapp -B /build/myapp -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_PREFIX_PATH="/opt/qt6;/usr/local" \
    && cmake --build /build/myapp -j"$(nproc)" \
    && cmake --install /build/myapp

FROM ghcr.io/nostalpixel/awslinux-cutelyst:latest
COPY --from=dev /usr/local/bin/myapp /usr/local/bin/myapp
CMD ["/usr/local/bin/myapp", "--server"]
```

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
