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

NetCDFが標準の探索場所にない場合は、インストールprefixを指定します。

```bash
export NetCDF_ROOT=/path/to/nvhpc-netcdf
```

## 推奨するコンパイル確認

リポジトリのトップディレクトリで実行します。

```bash
./tools/build_nvhpc.sh
```

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
| wrapperを見つけられない | `WW3_NVHPC_MPIFORT`と`WW3_NVHPC_MPICC`を設定します。 |
| 以前のcompilerが使われる | 別のbuild directoryを指定します。CMakeはcompiler情報をbuild directoryにcacheします。 |
| OpenACC時にGPU指定で失敗 | 実機のcompute capabilityと`-gpu=ccXY`、HPC SDKが対応するCUDA toolchainを確認します。 |

## このリポジトリでの検証範囲

この環境の作成時点では作業機がmacOSで、NVIDIA HPC SDKはLinux向けのため、
実際の`nvfortran`コンパイルは実施していません。shell/CMake構文と既存GNU CPU
ビルドへの回帰がないことを確認し、NVHPCでの実コンパイルは対象Linux環境で行います。

## 参考資料

- [CMake 3.20 release notes（NVHPC compiler ID追加）](https://cmake.org/cmake/help/latest/release/3.20.html)
- [CMake compiler ID一覧](https://cmake.org/cmake/help/latest/variable/CMAKE_LANG_COMPILER_ID.html)
- [NVIDIA HPC Compilers User's Guide](https://docs.nvidia.com/hpc-sdk/compilers/hpc-compilers-user-guide/index.html)
- [NVIDIA OpenACC Getting Started Guide](https://docs.nvidia.com/hpc-sdk/compilers/openacc-gs/index.html)
