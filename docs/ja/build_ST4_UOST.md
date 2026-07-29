# `ST4_UOST`ビルド手順と確認結果

## 確認済み環境

2026-07-29に以下の環境でReleaseビルドを確認しました。

| 項目 | 確認値 |
|---|---|
| OS・アーキテクチャ | macOS arm64 |
| GNU Fortran | 16.1.0 |
| Open MPI | 5.0.9 |
| CMake | 4.3.4 |
| NetCDF-C | 4.10.0 |
| NetCDF-Fortran | 4.6.3 |

## 依存パッケージ

Homebrewを使用する場合:

```sh
brew install gcc open-mpi cmake netcdf netcdf-fortran
```

## CMake構成

リポジトリのルートで実行します。

```sh
CC=/opt/homebrew/bin/mpicc \
FC=/opt/homebrew/bin/mpifort \
cmake -S . -B build \
  -DSWITCH="$PWD/model/bin/switch_ST4_UOST" \
  -DCMAKE_PREFIX_PATH=/opt/homebrew \
  -DCMAKE_BUILD_TYPE=Release
```

構成時に次を確認します。

- Fortran compilerがGNUとして認識される
- `NetCDF::NetCDF_C`と`NetCDF::NetCDF_Fortran`が見つかる
- `MPI_Fortran`が見つかる
- `Configuring done`、`Generating done`で終了する

## コンパイル

```sh
cmake --build build --parallel 8
```

確認結果:

- ビルド進捗100%
- 終了コード0
- 静的ライブラリ`build/lib/libww3.a`を生成
- Load Module 21種類を生成

## 生成されたLoad Module

すべて`build/bin`に生成されます。

| 分類 | Load Module |
|---|---|
| 主計算 | `ww3_shel`, `ww3_multi` |
| 格子・初期化 | `ww3_grid`, `ww3_strt` |
| 外力・境界前処理 | `ww3_prnc`, `ww3_bound`, `ww3_bounc`, `ww3_prep` |
| 補間・分割 | `ww3_gint`, `ww3_gspl` |
| 格子後処理 | `ww3_outf`, `ww3_ounf`, `gx_outf` |
| 地点後処理 | `ww3_outp`, `ww3_ounp`, `gx_outp` |
| その他 | `ww3_grib`, `ww3_trck`, `ww3_trnc`, `ww3_systrk`, `ww3_uprstr` |

合計はWW3系19種類、GrADS用2種類です。

## 確認された警告

GNU Fortran 16.1.0では、既存コードの一部に対して次の警告が出ます。

```text
Warning: Legacy Extension: Missing comma in FORMAT string
```

リンク時には次の警告が出ます。

```text
ld: warning: ignoring duplicate libraries: '-lnetcdf'
```

いずれも今回のビルドではエラーにならず、全Load Moduleが生成されました。
ただし、将来コンパイラの警告をエラー扱いにする場合は修正が必要です。

## リンク確認

`ww3_shel`は次のライブラリへリンクされることを確認しました。

- NetCDF-Fortran
- NetCDF-C
- Open MPI Fortran/C
- GNU Fortran runtime

macOSでは以下で確認できます。

```sh
otool -L build/bin/ww3_shel
```

## クリーン再ビルド

switchやコンパイラを変更する場合は、別のビルドディレクトリを使う方法が
安全です。

```sh
CC=/opt/homebrew/bin/mpicc \
FC=/opt/homebrew/bin/mpifort \
cmake -S . -B /private/tmp/test_WWIII-build-debug \
  -DSWITCH="$PWD/model/bin/switch_ST4_UOST" \
  -DCMAKE_PREFIX_PATH=/opt/homebrew \
  -DCMAKE_BUILD_TYPE=Debug

cmake --build /private/tmp/test_WWIII-build-debug --parallel 8
```

`build`および一時ビルドディレクトリは生成物であり、Gitには登録しません。
