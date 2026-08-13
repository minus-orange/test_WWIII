# Intel oneAPI legacy build（WW3本体はCMake不使用）

## 概要

Intel oneAPIの`ifx`を使い、WW3標準の`w3_setup`、`w3_make`、生成Makefileで6本を
ビルドする。前処理・後処理5本は`switch_ST4_UOST_SHRD`、MPI計算本体`ww3_shel`は
`switch_ST4_UOST`を使用する。NVHPC版とは依存ライブラリ、LM、中間生成物を分離する。

```text
oneAPI環境を有効化
  → 依存source archiveをダウンロード
  → icx/ifxで依存ライブラリを構築
  → w3_setup -c oneapi -s ST4_UOST_SHRD
  → w3_make ww3_grid ww3_strt ww3_prnc ww3_ounf ww3_ounp
  → w3_setup -c oneapi -s ST4_UOST
  → w3_make ww3_shel
  → model/exeに6本のLMを保持
```

WW3本体のビルドにはCMakeを使わない。zlib、HDF5、NetCDF-C、
NetCDF-Fortranの構築にはCMakeを使用する。

## 前提

- Linux x86_64
- Intel oneAPI Base ToolkitおよびHPC Toolkit
- `ifx`、`icx`、Intel MPIの`mpiifx`
- CMake、make、tar、curl
- 空白を含まないWW3 source path

oneAPI環境の有効化例:

```bash
source /opt/intel/oneapi/setvars.sh
```

module環境では、管理者が用意したcompilerとMPIのmoduleをloadする。確認する。

```bash
ifx --version
icx --version
mpiifx -show
```

`ww3_shel`はMPI版なので、`mpiifx -show`の出力に`ifx`が含まれる必要がある。
wrapper名が異なる場合は`WW3_ONEAPI_MPIFC=mpifort`などを指定する。

## 1. ライブラリsourceのダウンロード

```bash
./tools/download_oneapi_libraries.sh
```

ネットワークを使うのはこの手順だけである。SHA-256を検査した次のsource archiveが
`external/oneapi-libs/downloads`へ残る。

- zlib 1.3.2
- HDF5 1.14.6
- NetCDF-C 4.10.1
- NetCDF-Fortran 4.6.4

## 2. ライブラリのコンパイル

```bash
./tools/build_oneapi_libraries.sh
```

`icx`でzlib、HDF5、NetCDF-Cを、`ifx`でNetCDF-Fortranを構築する。
全ライブラリは共有ライブラリとして`external/oneapi-libs/install`へ入る。
download、展開source、build directory、install結果はいずれも削除しない。

既にダウンロード済みのarchiveだけを検査する場合:

```bash
./tools/download_oneapi_libraries.sh --verify-only
```

## 3. WW3本体のコンパイル

```bash
./tools/build_oneapi_legacy.sh
```

scriptは`ifx`、`icx`、MPI wrapper、NetCDF utilityを確認し、MPI wrapperと
NetCDF-Fortranがともに`ifx`を使用していない場合はビルド前に停止する。
また、`comp.oneapi`、`link.oneapi`、`ad3.oneapi`をWW3のtemplateから毎回生成する。
このため、対象sourceの`w3_setup`が`oneapi`をtemplate生成対象として認識しない版でも、
専用driver fileを優先してビルドできる。
ビルド中はWW3標準の`model/exe`、`model/obj_MPI`、`model/mod_MPI`を使用するが、
これらはoneAPI専用の`model/.legacy-builds/oneapi`配下へのsymlinkである。
oneAPI版LMの恒久的な場所は`model/.legacy-builds/oneapi/exe`である。
`oneapi_debug`を指定した場合も別の`model/.legacy-builds/oneapi_debug`へ保存する。

既定で次の6本を生成する。

```bash
./tools/build_oneapi_legacy.sh
# ww3_grid ww3_strt ww3_prnc ww3_ounf ww3_ounp ww3_shel
```

これ以外の古いWW3 LMはoneAPI側の`exe`ディレクトリから除外される。

debug build:

```bash
WW3_LEGACY_COMPILER=oneapi_debug ./tools/build_oneapi_legacy.sh
```

外部のoneAPI版NetCDFを使う場合:

```bash
WW3_NETCDF_ROOT=/path/to/oneapi-netcdf ./tools/build_oneapi_legacy.sh
```

## 4. 小規模実行確認

既存のUOSTスモークテストはcompilerに依存しないため、oneAPI版LMも実行できる。
表示上の名称はNVHPCのままだが、`WW3_BIN_DIR`で`model/exe`を明示する。

```bash
WW3_BIN_DIR="$PWD/model/exe" ./tools/run_nvhpc_uost_test.sh
./tools/check_nvhpc_uost_test.sh
```

## NVHPC版との分離

| 項目 | Intel oneAPI | NVIDIA HPC SDK |
|---|---|---|
| Fortran | `ifx` | `nvfortran` |
| C | `icx` | `nvc` |
| MPI | `mpiifx`（`ww3_shel`のみ） | `mpifort`（`ww3_shel`のみ） |
| ライブラリ | `external/oneapi-libs` | `external/nvhpc-libs` |
| scratch | `model/tmp-oneapi-legacy` | `model/tmp-nvhpc-legacy` |
| compiler設定 | `oneapi` | `nvhpc` |

`tools/select_legacy_build_tree.sh`がWW3標準の生成先をcompiler別directoryへ
切り替える。NVHPC版は`model/.legacy-builds/nvhpc`、oneAPI版は
`model/.legacy-builds/oneapi`に保持される。`model/exe`は最後に選択したcompilerの
LM directoryを指す。更新前から存在する生成物はcompilerを推測せず、初回実行時に
`model/.legacy-builds/unclassified-*`へ退避する。

## `comp.oneapi not found`が表示される場合

`build_oneapi_legacy.sh`だけが新しく、`prepare_oneapi_legacy_drivers.sh`がコピーされて
いない場合に発生する。最新版ではビルド前に3個のoneAPI driver fileを自動生成する。
リポジトリ全体を更新するか、少なくとも次を同時にコピーする。

```text
tools/build_oneapi_legacy.sh
tools/prepare_oneapi_legacy_drivers.sh
model/bin/comp.tmpl
model/bin/link.tmpl
model/bin/ad3.tmpl
```

## 制限事項

このMacにはIntel oneAPI Linux環境がないため、ここではshell構文、設定生成、
依存関係までを確認対象とする。実compilerによる最終ビルドは対象Linux環境で行う。
エラー共有は写真または短いテキストを前提とするため、`w3_make`のcompiler診断と
linker診断は端末へ表示される。
