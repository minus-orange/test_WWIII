# NVIDIA HPC SDK legacy build（CMake不使用）

## 概要

WW3標準の`w3_setup`、`w3_make`、生成Makefileを使い、CMakeを使用せずに
`switch_ST4_UOST`構成をビルドする。既存のCMake版とは独立した選択肢であり、
物理switchと使用ライブラリは同じである。

```text
w3_setup -c nvhpc -s ST4_UOST
  → comp/link/ad3生成
  → switch設定
  → w3_make
  → model/exeにLM生成
```

legacy scriptの制約により、リポジトリの絶対パスに空白を含めることはできない。
対象Linux環境の`test_WWIII`パスはこの条件を満たす。

## 前提

ライブラリのダウンロードとコンパイルは、CMake版と同じ独立手順を使用する。

```bash
module load hpc_sdk/nvhpc/26.3
./tools/download_nvhpc_libraries.sh
./tools/build_nvhpc_libraries.sh
```

ライブラリ構築にはCMakeを使用するが、WW3本体の以下のビルドではCMakeを使用しない。
NetCDF-C、NetCDF-Fortran、HDF5、zlibまでCMakeなしにするものではない。

## WW3本体のビルド

```bash
module load hpc_sdk/nvhpc/26.3
./tools/build_nvhpc_legacy.sh
```

scriptは次を事前確認する。

- `nvfortran`、`mpifort`、`mpicc`、`cc`、`ar`、`make`の存在
- `mpifort`が内部で`nvfortran`を使用していること
- NetCDF-Fortranが`nvfortran`で作成されていること
- `switch_ST4_UOST`の存在

`cc`がmodule環境にない場合は、対象計算機のGCC moduleもloadする。

生成先はWW3標準の`model/exe`である。中間生成物は`model/obj_MPI`、
`model/mod_MPI`、`model/tmp-nvhpc-legacy`に置かれる。

## NetCDF config互換wrapper

WW3 legacy buildは1個の`NETCDF_CONFIG`に対して、NetCDF-Cの`--libs`と
NetCDF-Fortranの`--flibs`の両方を要求する。現在の`nc-config`と`nf-config`は
それぞれ片方だけを提供するため、`tools/nvhpc_netcdf_config.sh`が要求を振り分ける。

| WW3からの要求 | 呼び出すutility |
|---|---|
| `--version`、`--has-nc4`、`--libs` | `nc-config` |
| `--fc`、`--cflags`、`--flibs` | `nf-config` |

## 設定変更

NetCDFが既定の`external/nvhpc-libs/install`以外にある場合:

```bash
WW3_NETCDF_ROOT=/path/to/nvhpc-netcdf \
  ./tools/build_nvhpc_legacy.sh
```

並列コンパイル数を変更する場合:

```bash
WW3_JOBS=16 ./tools/build_nvhpc_legacy.sh
```

一部LMだけを先に確認する場合:

```bash
WW3_LEGACY_PROGRAMS="ww3_grid ww3_strt ww3_shel ww3_ounf" \
  ./tools/build_nvhpc_legacy.sh
```

既定は`w3_make`が選択する全LMをビルドする。

debug buildでは次を指定する。

```bash
WW3_LEGACY_COMPILER=nvhpc_debug ./tools/build_nvhpc_legacy.sh
```

## 実行確認

スモークテストへlegacy buildのLM directoryを渡す。

```bash
WW3_BIN_DIR="$PWD/model/exe" ./tools/run_nvhpc_uost_test.sh
./tools/check_nvhpc_uost_test.sh
```

`DIST MPI`構成のため、前処理を含むLMはHPC-Xの`mpirun`経由で実行される。

## CMake版との違い

| 項目 | CMake版 | legacy版 |
|---|---|---|
| 起動script | `tools/build_nvhpc.sh` | `tools/build_nvhpc_legacy.sh` |
| build system | CMake | `w3_setup`＋`w3_make`＋Makefile |
| LM生成先 | `build-nvhpc/bin` | `model/exe` |
| 中間生成物 | out-of-source | `model/obj_MPI`など |
| switch | `switch_ST4_UOST` | `switch_ST4_UOST` |
| compiler/MPI | NVHPC/HPC-X | NVHPC/HPC-X |
