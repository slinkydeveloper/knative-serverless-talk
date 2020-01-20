# Rust factorial function

## Build it

In order to build the function, you must install `musl` and rustc `x86_64-unknown-linux-musl` target installed.
To install `musl` look at the [official documentation](https://www.musl-libc.org/), while to install the rustc target look at [rust documentation](https://doc.rust-lang.org/edition-guide/rust-2018/platform-and-target-support/musl-support-for-fully-static-binaries.html)

Then run for a debug build:

```
cargo build
```

For a release build:

```
cargo build --release
```

## Docker image

To build the docker image you must build the function in release mode:

```
docker build .
```
