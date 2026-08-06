# NVIDIA HPC SDK MPI toolchain for the standalone WW3 CMake build.
#
# The MPI wrappers must resolve to nvfortran and nvc. Override their names or
# paths with WW3_NVHPC_MPIFORT and WW3_NVHPC_MPICC when they are not on PATH.

if(CMAKE_VERSION VERSION_LESS 3.20)
  message(FATAL_ERROR
    "The NVHPC compiler ID requires CMake 3.20 or newer. "
    "Found CMake ${CMAKE_VERSION}.")
endif()

set(_ww3_mpifort_names mpifort mpif90)
if(DEFINED ENV{WW3_NVHPC_MPIFORT} AND NOT "$ENV{WW3_NVHPC_MPIFORT}" STREQUAL "")
  list(PREPEND _ww3_mpifort_names "$ENV{WW3_NVHPC_MPIFORT}")
endif()

set(_ww3_mpicc_names mpicc)
if(DEFINED ENV{WW3_NVHPC_MPICC} AND NOT "$ENV{WW3_NVHPC_MPICC}" STREQUAL "")
  list(PREPEND _ww3_mpicc_names "$ENV{WW3_NVHPC_MPICC}")
endif()

find_program(WW3_NVHPC_MPIFORT_EXECUTABLE NAMES ${_ww3_mpifort_names})
find_program(WW3_NVHPC_MPICC_EXECUTABLE NAMES ${_ww3_mpicc_names})

if(NOT WW3_NVHPC_MPIFORT_EXECUTABLE)
  message(FATAL_ERROR
    "NVHPC MPI Fortran wrapper not found. Add the NVIDIA HPC SDK MPI bin "
    "directory to PATH or set WW3_NVHPC_MPIFORT.")
endif()
if(NOT WW3_NVHPC_MPICC_EXECUTABLE)
  message(FATAL_ERROR
    "NVHPC MPI C wrapper not found. Add the NVIDIA HPC SDK MPI bin "
    "directory to PATH or set WW3_NVHPC_MPICC.")
endif()

set(CMAKE_Fortran_COMPILER "${WW3_NVHPC_MPIFORT_EXECUTABLE}" CACHE FILEPATH
  "NVHPC-backed MPI Fortran compiler wrapper")
set(CMAKE_C_COMPILER "${WW3_NVHPC_MPICC_EXECUTABLE}" CACHE FILEPATH
  "NVHPC-backed MPI C compiler wrapper")

# Catch a common failure mode where PATH selects a GNU or Intel MPI wrapper.
set(WW3_REQUIRE_NVHPC ON CACHE BOOL
  "Require NVIDIA HPC SDK C and Fortran compilers" FORCE)

unset(_ww3_mpifort_names)
unset(_ww3_mpicc_names)
