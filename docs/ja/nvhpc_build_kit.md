# NVHPC移植用ビルドキット

生成済みarchiveは
[`artifacts/ww3-nvhpc-legacy-kit-0c67f422.tar.gz`](../../artifacts/ww3-nvhpc-legacy-kit-0c67f422.tar.gz)
としてGitにも登録している。

## 目的

別ディレクトリにあるWAVEWATCH III 7.14コードへ、NVIDIA HPC SDKの
`nvfortran`を使う非CMakeのlegacy build環境を移植する。WW3本体や依存ライブラリの
source archiveは同梱せず、`w3_setup`と`w3_make`用のNVHPC対応script、設定、
検証済みpatchだけをまとめる。WW3本体のCMake版は含めない。
依存ライブラリ（zlib、HDF5、NetCDF）の構築scriptは、従来どおり各ライブラリの
CMake buildを使用する。

対象となる上流sourceは`NOAA-EMC/WW3`の次のcommitである。

```text
c3b0d04d0d632641dab2dde7f053f4ab3ee35043
VERSION: 7.14
```

異なるWW3バージョンには適用しない。対象コードに独自変更がある場合、重なる変更を
自動上書きせず、patchの事前検査で停止する。

## キットの作成

このリポジトリで、出力先に存在しないディレクトリ名を指定する。

```bash
./tools/export_nvhpc_build_kit.sh /tmp/ww3-nvhpc-build-kit
```

次の2つが作成される。

```text
/tmp/ww3-nvhpc-build-kit/
/tmp/ww3-nvhpc-build-kit.tar.gz
```

tar archiveを対象計算機へコピーして展開できる。ライブラリarchiveは含まないため、
サイズは小さい。`SOURCE.txt`に元のWW3 commitとキット作成commit、`SHA256SUMS`に
全ファイルのchecksumを記録する。

## 別のWW3ディレクトリへの適用

```bash
tar -xzf ww3-nvhpc-build-kit.tar.gz
cd ww3-nvhpc-build-kit
./install.sh /path/to/other/WW3
```

installerは最初に`SHA256SUMS`を自動検証する。Linuxでは`sha256sum`、macOS等では
`shasum`を使用する。

指定するsource rootには、少なくとも次の構成が必要である。

```text
WW3_SOURCE_DIR/
├── VERSION
└── model/
    ├── bin/
    └── src/
```

指定directoryの4階層以内にこの構成が1個だけある場合は自動検出する。見つからない
場合は、検出した`VERSION`と`w3_setup`のpathを短く表示する。

適用前に全patchを`git apply --check`し、対象側の変更と衝突する場合は何も変更せず
停止する。以前の本リポジトリ製NVHPC kitを導入済みの場合は、既知の旧版から
最新版への専用差分patchを自動選択する。旧kitとchecksumが一致するsupport fileも
安全に更新され、`Upgrading an earlier NVHPC kit`と更新経路が表示される。

ただし、NVHPC設定とは独立した`w3gridmd.F90`と`ww3_sbs1.F90`の上流
不整合修正はoptional patchとして分離している。対象側の実装が異なる場合は警告して
省略し、NVHPC legacy build環境の導入を継続する。追加するsupport fileが既に異なる
内容で存在する場合は停止する。
内容を確認して置換する場合だけ`--force`を指定する。`--force`でもsource patchの
衝突は無視しない。既知の旧kitとも一致しない独自変更は従来どおり自動上書きしない。

## 含まれるファイル

共通:

- `download_nvhpc_libraries.sh`: 固定versionとSHA-256によるdownload
- `build_nvhpc_libraries.sh`: zlib、HDF5、NetCDF-C/FortranのNVHPC build
- `nvhpc_library_versions.sh`: version、URL、checksum
- `check_netcdf.f90`: `netcdf.mod`のcompile/link確認
- `select_legacy_build_tree.sh`: compiler別のLM・object・module生成先切替
- `prepare_legacy_program_set.sh`: 指定LMだけを生成・保持するための事前整理
- `switch_ST4_UOST`: 今回確認した物理switch
- `switch_ST4_UOST_SHRD`: 前処理・後処理用の非MPI switch
- `mod_timer.F90`: `totalnoregion`を最外周とする最大4階層のMPI集約タイマーmodule
- UOST smoke testの実行・結果確認script

legacy build:

- `build_nvhpc_legacy.sh`
- `nvhpc_netcdf_config.sh`
- `cmplr.env`、`w3_setup`、`w3_make`、依存解析・診断表示・タイマー計装のpatch

共通patchには、ST4_UOSTでNVHPCが検出したWW3 7.14上流sourceの2件の不整合修正も
含む。

smoke testが途中停止した場合、実行scriptは停止LM、終了code、log末尾40行をその場で
表示する。結果確認scriptも後続file欠落を多数列挙せず、一次障害1件と同じlog末尾だけを
表示する。

## 適用後のコンパイル

対象計算機でNVIDIA HPC SDKをloadして実行する。

```bash
module load hpc_sdk/nvhpc/26.3

cd /path/to/other/WW3
./tools/download_nvhpc_libraries.sh
./tools/build_nvhpc_libraries.sh
```

```bash
./tools/build_nvhpc_legacy.sh
```

既存のNVHPC版NetCDFを使う場合はdownload/buildを省略し、そのprefixを指定する。

```bash
WW3_NETCDF_ROOT=/path/to/nvhpc-netcdf ./tools/build_nvhpc_legacy.sh
```

## 対象コードに独自変更がある場合

installerがpatch衝突で停止した場合、`patches/*.patch`を参照し、対象コードへ手動で
移植する。特に`model/bin/build_utils.sh`と`model/bin/w3_make`はWW3バージョン間で
変わりやすいため、別versionへ機械的に適用しない。
