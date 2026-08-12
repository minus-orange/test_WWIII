# NVHPC移植用ビルドキット

## 目的

別ディレクトリにあるWAVEWATCH III 7.14コードへ、NVIDIA HPC SDKの
`nvfortran`を使うビルド環境を移植する。WW3本体や依存ライブラリのsource archiveは
同梱せず、NVHPC対応script、設定、検証済みpatchだけをまとめる。

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
./install.sh --mode all /path/to/other/WW3
```

installerは最初に`SHA256SUMS`を自動検証する。Linuxでは`sha256sum`、macOS等では
`shasum`を使用する。

modeは次から選べる。

| mode | 内容 |
|---|---|
| `all` | CMake版とlegacy版の両方（既定） |
| `cmake` | WW3標準CMakeを使用するNVHPC build |
| `legacy` | `w3_setup`と`w3_make`を使用する非CMake build |

適用前に全patchを`git apply --check`し、対象側の変更と衝突する場合は何も変更せず
停止する。追加するsupport fileが既に異なる内容で存在する場合も停止する。
内容を確認して置換する場合だけ`--force`を指定する。`--force`でもsource patchの
衝突は無視しない。

## 含まれるファイル

共通:

- `download_nvhpc_libraries.sh`: 固定versionとSHA-256によるdownload
- `build_nvhpc_libraries.sh`: zlib、HDF5、NetCDF-C/FortranのNVHPC build
- `nvhpc_library_versions.sh`: version、URL、checksum
- `check_netcdf.f90`: `netcdf.mod`のcompile/link確認
- `switch_ST4_UOST`: 今回確認した物理switch
- UOST smoke testの実行・結果確認script

CMake版:

- `build_nvhpc.sh`
- `cmake/toolchains/nvhpc-mpi.cmake`
- NVHPC compiler IDを有効にするCMake patch

legacy版:

- `build_nvhpc_legacy.sh`
- `nvhpc_netcdf_config.sh`
- `cmplr.env`、`w3_setup`、`w3_make`、依存解析・診断表示のpatch

共通patchには、ST4_UOSTでNVHPCが検出したWW3 7.14上流sourceの2件の不整合修正も
含む。

## 適用後のコンパイル

対象計算機でNVIDIA HPC SDKをloadして実行する。

```bash
module load hpc_sdk/nvhpc/26.3

cd /path/to/other/WW3
./tools/download_nvhpc_libraries.sh
./tools/build_nvhpc_libraries.sh
```

CMake版:

```bash
./tools/build_nvhpc.sh
```

legacy版:

```bash
./tools/build_nvhpc_legacy.sh
```

既存のNVHPC版NetCDFを使う場合はdownload/buildを省略し、そのprefixを指定する。

```bash
WW3_NETCDF_ROOT=/path/to/nvhpc-netcdf ./tools/build_nvhpc.sh
WW3_NETCDF_ROOT=/path/to/nvhpc-netcdf ./tools/build_nvhpc_legacy.sh
```

## 対象コードに独自変更がある場合

installerがpatch衝突で停止した場合、`patches/*.patch`を参照し、対象コードへ手動で
移植する。特に`model/src/CMakeLists.txt`、`model/bin/build_utils.sh`、
`model/bin/w3_make`はWW3バージョン間で変わりやすいため、別versionへ機械的に
適用しない。
