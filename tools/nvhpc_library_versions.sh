#!/usr/bin/env bash
# Pinned source archives used by download_nvhpc_libraries.sh and
# build_nvhpc_libraries.sh. Update version, URL, and SHA-256 together.

ZLIB_VERSION="1.3.2"
ZLIB_ARCHIVE="zlib-${ZLIB_VERSION}.tar.gz"
ZLIB_URL="https://zlib.net/fossils/${ZLIB_ARCHIVE}"
ZLIB_SHA256="bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16"

HDF5_VERSION="1.14.6"
HDF5_ARCHIVE="hdf5-${HDF5_VERSION}.tar.gz"
HDF5_URL="https://github.com/HDFGroup/hdf5/releases/download/hdf5_1.14.6/${HDF5_ARCHIVE}"
HDF5_SHA256="e4defbac30f50d64e1556374aa49e574417c9e72c6b1de7a4ff88c4b1bea6e9b"

NETCDF_C_VERSION="4.10.1"
NETCDF_C_ARCHIVE="netcdf-c-${NETCDF_C_VERSION}.tar.gz"
NETCDF_C_URL="https://github.com/Unidata/netcdf-c/archive/refs/tags/v${NETCDF_C_VERSION}.tar.gz"
NETCDF_C_SHA256="33c27231c478c3b35da7c7758fbdd02da1fe407abcb16ddfe195f69d164f930d"

NETCDF_FORTRAN_VERSION="4.6.4"
NETCDF_FORTRAN_ARCHIVE="netcdf-fortran-${NETCDF_FORTRAN_VERSION}.tar.gz"
NETCDF_FORTRAN_URL="https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v${NETCDF_FORTRAN_VERSION}.tar.gz"
NETCDF_FORTRAN_SHA256="fc8df99e78cd2aa5ea7b312bce5307b1bea73a118d4860b3b4358971ec376c54"
