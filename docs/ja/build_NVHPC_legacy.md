# NVIDIA HPC SDK legacy build（CMake不使用）

## 概要

WW3標準の`w3_setup`、`w3_make`、生成Makefileを使い、CMakeを使用せずに
NVHPCで6本のLMを作成する。前処理・後処理5本は`switch_ST4_UOST_SHRD`、MPI計算本体
`ww3_shel`は`switch_ST4_UOST`を使用する。既存のCMake版とは独立した選択肢である。

```text
w3_setup -c nvhpc -s ST4_UOST_SHRD
  → w3_make ww3_grid ww3_strt ww3_prnc ww3_ounf ww3_ounp
w3_setup -c nvhpc -s ST4_UOST
  → w3_make ww3_shel
  → model/exeに6本を保持
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

ビルド中はWW3標準の`model/exe`、`model/obj_MPI`、`model/mod_MPI`を使用するが、
これらはNVHPC専用の`model/.legacy-builds/nvhpc`配下へのsymlinkである。
実体をcompiler別に分離するため、oneAPI版を同じsource treeでビルドしても
NVHPC版が誤って`up to date`と判定されたり上書きされたりしない。
NVHPC版LMの恒久的な場所は`model/.legacy-builds/nvhpc/exe`である。
`nvhpc_debug`を指定した場合も別の`model/.legacy-builds/nvhpc_debug`へ保存する。

## NetCDF config互換wrapper

WW3 legacy buildは1個の`NETCDF_CONFIG`に対して、NetCDF-Cの`--libs`と
NetCDF-Fortranの`--flibs`の両方を要求する。現在の`nc-config`と`nf-config`は
それぞれ片方だけを提供するため、`tools/nvhpc_netcdf_config.sh`が要求を振り分ける。

また、上流のlegacy `w3_make`では`ww3_outp`などが非NetCDF programに分類されるが、
`NC4`構成の`w3iopomd`は無条件に`netcdf.mod`を使用する。本リポジトリでは`NC4`選択時に
全LMへNetCDFのcompile/link flagsを設定し、依存moduleをどの順序で構築しても
`netcdf.mod`を参照できるようにしている。

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

既定で次の6本を生成する。

```bash
./tools/build_nvhpc_legacy.sh
# ww3_grid ww3_strt ww3_prnc ww3_ounf ww3_ounp ww3_shel
```

これ以外の古いWW3 LMは、このcompilerの`exe`ディレクトリから除外される。

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

## トラブルシュート

| 症状 | 原因と対処 |
|---|---|
| `w3iopomd.F90`で`Unable to open MODULE file netcdf.mod` | 古い`w3_make`が`ww3_outp`を非NetCDF programとしてコンパイルしている。最新版へ`git pull`後、同じbuild scriptを再実行する。成功済みobjectは再利用されるため、手動削除は不要。 |
| `ww3_trnc`のリンクで`makefile:... Error 2` | `ww3_trnc`が使用する`W3IOGRMD`と、`NL1`時の`W3ADATMD`が元のlegacy依存リストにない。最新版では依存を補正済み。build scriptは古い生成makefileだけを自動更新し、成功済みobjectは再利用する。`git pull`後、同じbuild scriptを先頭から再実行する。 |
| `ww3_gint`のリンクで`w3iorsmd_w3iors_`が未解決 | restart補間処理で追加された`W3IORSMD`が元のlegacy依存リストにない。最新版では`ww3_gint`のlink対象へ追加済み。`git pull`後、同じbuild scriptを再実行する。 |
| `ww3_sbs1`で`NDSE has not been explicitly declared`と`Label 140 ... never defined` | 上流のlabel文削除時に残った2箇所の不整合。エラー出力unitを宣言済みの`MDSE`へ修正し、`IOSTAT`で処理済みのREAD文から削除済みlabelへの分岐を除去している。 |
| compilerを切り替えると全LMが`up to date`になる | 最新版では`model/.legacy-builds/<compiler>`へLM・object・moduleを分離する。更新前に存在した生成物は初回実行時に`unclassified-*`へ退避される。 |

リンクに再度失敗した場合は、最新版では`*** error in linking ***`以降に実際の
未解決symbol等が表示される。その末尾を写真で共有する。

コンパイルに失敗した場合も、最新版では`--- compiler diagnostics ---`の下へ
compilerのエラー本文を表示する。入力共有が写真または短いテキストに限られるため、
別ログを開かなくても原因箇所を確認できるようにしている。

## CMake版との違い

| 項目 | CMake版 | legacy版 |
|---|---|---|
| 起動script | `tools/build_nvhpc.sh` | `tools/build_nvhpc_legacy.sh` |
| build system | CMake | `w3_setup`＋`w3_make`＋Makefile |
| LM生成先 | `build-nvhpc/bin` | `model/exe` |
| 中間生成物 | out-of-source | `model/obj_MPI`など |
| switch | `switch_ST4_UOST` | `switch_ST4_UOST` |
| compiler/MPI | NVHPC/HPC-X | NVHPC/HPC-X |
