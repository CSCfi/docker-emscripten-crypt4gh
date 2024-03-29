# Emscripten docker image for compiling crypt4gh applications

This implementation was extracted from [swift-browser-ui](https://github.com/CSCfi/swift-browser-ui/blob/e1b2525be8a5b779dca524378746637e9bfab4ee/devproxy/Dockerfile-emsdk-deps).

This container makes it easy to compile `crypt4gh` applications built with `emscripten` into `wasm` without installing dependencies locally.


## Stack
The provided docker image is an extension of [emscripten/emsdk](https://hub.docker.com/r/emscripten/emsdk/tags) official docker image.

Included libraries
- [libsodium](https://libsodium.org)
- [openssl](https://www.openssl.org)
- [libcrypt4gh](https://github.com/CSCfi/libcrypt4gh)
- [libcrypt4gh-keys](https://github.com/CSCfi/libcrypt4gh-keys)

## How to use this container
Build the image with

    docker buildx build .

or download it

    docker pull ghcr.io/cscfi/docker-emscripten-crypt4gh:latest

Build your application

    docker run --rm -it --mount type=bind,source=${YOUR_APPLICATION_SOURCE_CODE},target=/src/ ghcr.io/cscfi/docker-emscripten-crypt4gh:latest YOUR-MAKEFILE-COMMAND-HERE

## Extras
You can provide argument variables to change which library versions get built.

`emscripten`, `libsodium`, and `openssl` versions can be changed with `--build-arg` by changing the value of `EMSCRIPTEN_VERSION`, `LIBSODIUM_VERSION`, `EMSDK_IMAGE` and `OPENSSL_VERSION`.

>__NOTE:__ To build only ARM images use -arm in version tag and for ARM built images. For example `EMSDK_IMAGE --build-arg="EMSDK_IMAGE=<local-registry>/emscripten/emsdk"  --build-arg="EMSCRIPTEN_VERSION=3.1.21-arm"` instructs to use locally build emsdk:3.1.21-arm container. 

# License

`docker-emscripten-crypt4gh` and its sources are released under MIT License.
