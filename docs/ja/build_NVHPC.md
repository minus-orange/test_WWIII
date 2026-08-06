# NVIDIA HPC SDKでのビルド環境

## 目的

`switch_ST4_UOST`を変更せず、WW3 7.14の標準CMakeビルドに沿って
NVIDIA HPC SDKの`nvfortran`で全load moduleをコンパイルするための環境です。
この段階ではOpenACC指示行を追加せず、CPU向けコンパイルの成立を確認します。
したがってコンパイル確認自体にNVIDIA GPUは不要です。

本対応では次を追加・修正しています。

- CMakeの現行コンパイラID `NVHPC`をWW3のNVIDIA/旧PGI用フラグ分岐で認識
- GNU Fortran専用の`-fallow-argument-mismatch`等をNVIDIA分岐から除外
- NVHPC版`mpifort`/`mpicc`を選ぶCMake toolchain file
- 誤ってGNU/Intel版MPI wrapperを選んだ場合のconfigure時エラー
- zlib、HDF5、NetCDF-C、NetCDF-Fortranの検証付きダウンロード・ビルドscript
- 同じconfigure/build手順を実行する`tools/build_nvhpc.sh`

## 前提環境

- NVIDIA HPC SDKをサポートするLinux x86-64またはLinux Armサーバー
- CMake 3.20以上（`NVHPC` compiler IDの認識に必要）
- NVIDIA HPC SDKのOpen MPI
- NVHPCでビルドされたNetCDF-CおよびNetCDF-Fortran

Fortranの`.mod`ファイルにはコンパイラ互換性がありません。NetCDF-Fortranも
`nvfortran`でビルドされたものを使用してください。サイトのmodule環境があれば、
まずNVHPC、NVHPC版MPI、NVHPC版NetCDFのmoduleをloadします。

```bash
module load nvhpc
module load netcdf-c
module load netcdf-fortran
```

module名は計算機環境ごとに異なります。HPC SDK付属MPIを直接使う場合は、使用する
SDKバージョンの`mpi/openmpi/bin`を`PATH`の先頭に追加してください。

## wrapperの事前確認

```bash
nvfortran --version
mpifort --showme:command
mpicc --showme:command
nf-config --fc
```

`mpifort --showme:command`が`nvfortran`、`mpicc --showme:command`が`nvc`を
示すことを確認します。環境によって`--showme:command`が使えない場合は
`mpifort -show`、`mpicc -show`を使用します。

wrapperが標準名でない場合、絶対パスを指定できます。

```bash
export WW3_NVHPC_MPIFORT=/path/to/nvhpc/mpi/openmpi/bin/mpifort
export WW3_NVHPC_MPICC=/path/to/nvhpc/mpi/openmpi/bin/mpicc
```

## NetCDF依存ライブラリの準備

画像の`NetCDF_C_LIBRARY-NOTFOUND`と`NetCDF_Fortran_LIBRARY-NOTFOUND`は、
NVHPCで利用できるNetCDF-C／NetCDF-Fortranが環境にないことを示します。
アーカイブはサイズが大きく、上流のライセンス・更新・改変履歴も分離して管理するため、
Gitには含めません。代わりに公式配布元、バージョン、SHA-256を固定したscriptを
登録しています。

| ライブラリ | 固定バージョン | 用途 |
|---|---:|---|
| zlib | 1.3.2 | HDF5圧縮filter |
| HDF5 | 1.14.6 | NetCDF-4形式 |
| NetCDF-C | 4.10.1 | NetCDF本体とC API |
| NetCDF-Fortran | 4.6.4 | `netcdf.mod`とFortran API |

NVHPC moduleをloadした後、次の2段階を実行します。

```bash
module load hpc_sdk/nvhpc/26.3

# 1. 公式source archiveをダウンロードしSHA-256を検証
./tools/download_nvhpc_libraries.sh

# 2. nvc/nvfortranでコンパイル・インストール
./tools/build_nvhpc_libraries.sh
```

既定では`external/nvhpc-libs`以下を使用します。このディレクトリは`.gitignore`対象です。

| directory | 内容 |
|---|---|
| `external/nvhpc-libs/downloads` | 検証済みsource archive |
| `external/nvhpc-libs/sources` | 展開したsource |
| `external/nvhpc-libs/build` | 各ライブラリのbuild tree |
| `external/nvhpc-libs/install` | WW3から参照するinstall prefix |

ダウンロードとコンパイルは明確に分離しています。`build_nvhpc_libraries.sh`は
ネットワークへ接続せず、事前にダウンロードされた全archiveのSHA-256が一致する場合だけ
コンパイルを開始します。archiveが不足している、または破損している場合は停止するため、
必ず先に`download_nvhpc_libraries.sh`を実行してください。

インターネット接続できない計算機では、接続可能な端末でダウンロードscriptを実行し、
`downloads`ディレクトリだけを計算機へコピーしてください。build scriptは各archiveを
再度SHA-256検証します。

保存先と並列数は環境変数で変更できます。

```bash
WW3_LIB_ROOT=/work/k-hanagata/ww3-nvhpc-libs \
  ./tools/download_nvhpc_libraries.sh

WW3_LIB_ROOT=/work/k-hanagata/ww3-nvhpc-libs \
  WW3_LIB_JOBS=16 \
  ./tools/build_nvhpc_libraries.sh
```

ライブラリ付属testも実行する場合は`WW3_LIB_RUN_TESTS=ON`を指定します。既定は
コンパイル確認を優先して`OFF`です。いずれの場合も最後に`netcdf.mod`を使用する
小さなFortran programをコンパイル・リンク・実行し、C APIまで到達できることを
確認します。

```bash
WW3_LIB_RUN_TESTS=ON ./tools/build_nvhpc_libraries.sh
```

この構成はWW3に不要なDAP、NCZarr、S3、libxml2、外部圧縮pluginとparallel HDF5を
無効化し、shared libraryのみを作って依存関係を最小化しています。WW3自体のMPI並列
実行は引き続き利用できます。

NetCDFを別の場所へインストールした場合は、そのprefixを指定します。

```bash
export WW3_NETCDF_ROOT=/path/to/nvhpc-netcdf
```

共有ライブラリを実行時に発見できない環境では、次も設定します。

```bash
export LD_LIBRARY_PATH=/path/to/nvhpc-netcdf/lib:/path/to/nvhpc-netcdf/lib64:${LD_LIBRARY_PATH:-}
```

## 推奨するコンパイル確認

リポジトリのトップディレクトリで実行します。

```bash
./tools/build_nvhpc.sh
```

既定の`external/nvhpc-libs/install`にライブラリを作成した場合、
`build_nvhpc.sh`が自動検出します。NetCDFが見つからない場合は、CMakeを開始する前に
`build_nvhpc_libraries.sh`の実行方法を表示して終了します。

デフォルト値は次のとおりです。

| 項目 | 値 |
|---|---|
| build directory | `build-nvhpc` |
| switch | `model/bin/switch_ST4_UOST` |
| build type | `Release` |
| parallel jobs | 4 |

環境変数で変更できます。

```bash
WW3_BUILD_DIR=/work/ww3-build-nvhpc \
WW3_JOBS=16 \
./tools/build_nvhpc.sh
```

追加のCMake引数はスクリプト引数として渡せます。

```bash
./tools/build_nvhpc.sh -DNetCDF_ROOT=/path/to/nvhpc-netcdf
```

## WW3標準CMakeコマンドで直接実行する場合

スクリプトは次の標準的なout-of-source buildをまとめたものです。

```bash
cmake -S . -B build-nvhpc \
  -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/nvhpc-mpi.cmake \
  -DSWITCH=model/bin/switch_ST4_UOST \
  -DCMAKE_BUILD_TYPE=Release \
  -DNetCDF_ROOT=/path/to/nvhpc-netcdf
cmake --build build-nvhpc --parallel 4
```

configureログのFortran compiler identificationが`NVHPC`であることを確認します。
正常終了後、21種類のload moduleが`build-nvhpc/bin`に作成されます。

## コンパイル後の実行確認

作成したload moduleは、小規模な13×12格子の公式UOST回帰ケースで確認できます。
実行と結果検査は別scriptです。

```bash
./tools/run_nvhpc_uost_test.sh
./tools/check_nvhpc_uost_test.sh
```

詳細は[NVHPC版UOSTスモークテスト](nvhpc_smoke_test.md)を参照してください。

## OpenACCコンパイラ確認（任意・次段階向け）

OpenACC指示行の実装前でも、OpenACC runtimeを含むコンパイル・リンク経路だけを
確認できます。GPUのcompute capabilityに合わせて`cc80`を変更してください。

```bash
WW3_BUILD_DIR=/work/ww3-build-nvhpc-acc \
WW3_NVHPC_FLAGS="-acc -gpu=cc80 -Minfo=accel" \
./tools/build_nvhpc.sh
```

`-acc`はコンパイルとリンクの両方で必要です。ここで成功しても、まだ物理処理が
GPUで高速化されたことは意味しません。OpenACC指示行追加後の基準比較は別途行います。

## 確認結果として保存するとよい情報

```bash
cmake --build build-nvhpc --verbose
find build-nvhpc/bin -maxdepth 1 -type f -print | sort
mpifort --showme:command
nvfortran --version
nf-config --all
```

実行環境のコンパイルログ、HPC SDK/NetCDFのバージョン、生成LM一覧を保存すると、
今後のOpenACC版との比較や問題の切り分けに利用できます。

## 主なトラブルと対処

| 症状 | 原因と対処 |
|---|---|
| `WW3_REQUIRE_NVHPC`エラー | GNU/Intel版MPI wrapperを選択しています。HPC SDK MPIの`bin`を`PATH`の先頭に置くか、wrapperの絶対パスを指定します。 |
| `netcdf.mod`を読めない | NetCDF-Fortranのコンパイラ不一致が疑われます。NVHPCでビルドしたNetCDFを指定します。 |
| `NetCDF_*_LIBRARY-NOTFOUND` | `./tools/build_nvhpc_libraries.sh`を実行し、同じprefixのNetCDF-CとNetCDF-Fortranを指定します。 |
| wrapperを見つけられない | `WW3_NVHPC_MPIFORT`と`WW3_NVHPC_MPICC`を設定します。 |
| 以前のcompilerが使われる | 別のbuild directoryを指定します。CMakeはcompiler情報をbuild directoryにcacheします。 |
| `ww3_strt`が`help-opal-runtime.txt`、`MPI_Init`で停止 | 移設されたHPC-XのLMを直接起動しています。コンパイル時と同じmoduleをloadし、`mpirun -np 1`経由で起動します。スモークテストscriptは全LMにこの起動方法を使用します。 |
| OpenACC時にGPU指定で失敗 | 実機のcompute capabilityと`-gpu=ccXY`、HPC SDKが対応するCUDA toolchainを確認します。 |

## このリポジトリでの検証範囲

2026年8月6日に対象Linux環境のNVIDIA HPC SDK 26.3で実コンパイルとリンクが完了し、
21種類のload moduleが生成された。`ldd`ではNVHPCで作成したNetCDF-Fortran、
NetCDF-C、HDF5、zlibとHPC-X MPIが解決され、`not found`がないことを確認した。
計算結果の確認は上記スモークテストで行う。

## 参考資料

- [CMake 3.20 release notes（NVHPC compiler ID追加）](https://cmake.org/cmake/help/latest/release/3.20.html)
- [CMake compiler ID一覧](https://cmake.org/cmake/help/latest/variable/CMAKE_LANG_COMPILER_ID.html)
- [NVIDIA HPC Compilers User's Guide](https://docs.nvidia.com/hpc-sdk/compilers/hpc-compilers-user-guide/index.html)
- [NVIDIA OpenACC Getting Started Guide](https://docs.nvidia.com/hpc-sdk/compilers/openacc-gs/index.html)
- [Unidata NetCDF-C CMake build instructions](https://docs.unidata.ucar.edu/netcdf-c/current/netCDF-CMake.html)
- [Unidata NetCDF-C releases](https://github.com/Unidata/netcdf-c/releases)
- [Unidata NetCDF-Fortran releases](https://github.com/Unidata/netcdf-fortran/releases)
- [HDF5 releases](https://github.com/HDFGroup/hdf5/releases)
- [zlib source releases](https://zlib.net/)
