# CPU基準テスト

## 結論

2026年8月4日に、macOS arm64上のGNU Fortran CPUビルドで次の3ケースを
実行した。いずれも格子前処理、初期化、`ww3_shel`の時間積分を完走し、
終了コードは0だった。

| ケース | 主な確認対象 | モデル期間 | `ww3_shel`実測時間 |
|---|---|---:|---:|
| `ww3_tp1.1` / `PR3_UQ` | 1次元伝播と入出力 | 24日 | 0.19 s |
| `ww3_ts1` / `ST4` | `LN1 ST4 NL1 BT1 DB1`ソース項 | 36時間 | 3.25 s |
| `ww3_ts4/input_rg_shel` | `UOST`障害物ソース項 | 48時間 | 1.23 s |

実測時間は性能保証値ではなく、実行規模の目安である。数値基準とSHA-256は
[`baselines/cpu/macos-arm64-gfortran16`](../../baselines/cpu/macos-arm64-gfortran16/README.md)
に記録した。

## 確認環境

| 項目 | 値 |
|---|---|
| OS | macOS 26.5.2 (25F84) |
| アーキテクチャ | arm64 |
| GNU Fortran | 16.1.0 |
| Open MPI | 5.0.9 |
| CMake | 4.3.4 |
| NetCDF-C | 4.10.0 |
| NetCDF-Fortran | 4.6.3 |
| CMake build type | Release (`-O3`) |

## ソース修正

UOSTケースの初回実行で、GNU Fortran 16が
`model/src/w3gridmd.F90`のFORMAT文にある記述子間のカンマ欠落を検出し、
`ww3_grid`が停止した。次の構文修正後にUOSTケースは完走した。

```fortran
! 修正前
F5.2', UOSTFACTORSHADOW = '

! 修正後
F5.2,', UOSTFACTORSHADOW = '
```

出力文字列を定義するFORMATの修正であり、物理計算には影響しない。

## 再実行

`run_cmake_test`はパス中の空白を正しく引用しないため、空白のないパスから
リポジトリを参照する。

```sh
ln -s "/Users/adabana/Documents/WWIII GPU化検討" /tmp/wwiii_gpu_baseline
cd /tmp/wwiii_gpu_baseline/regtests

export CMAKE_OPTIONS="-DCMAKE_PREFIX_PATH=/opt/homebrew \
-DCMAKE_Fortran_COMPILER=/opt/homebrew/bin/mpifort \
-DCMAKE_C_COMPILER=/opt/homebrew/bin/mpicc \
-DCMAKE_BUILD_TYPE=Release"
```

### 伝播スモークテスト

```sh
./bin/run_cmake_test \
  -s PR3_UQ -N -w work_cpu_baseline \
  ../model ww3_tp1.1
```

### ST4ソース項

```sh
./bin/run_cmake_test \
  -s ST4 -N -w work_cpu_baseline_ST4 \
  ../model ww3_ts1
```

### UOST

```sh
./bin/run_cmake_test \
  -N -i input_rg_shel -w work_cpu_baseline_UOST \
  ../model ww3_ts4
```

UOSTのNetCDF基準出力は、実行後に次の手順で生成する。

```sh
cd ww3_ts4/work_cpu_baseline_UOST
cp ../input_rg_shel/ww3_ounf.nml .
./exe/ww3_ounf
```

## 警告の扱い

- 3ケースとも終了時に`IEEE_UNDERFLOW_FLAG`が表示された。計算は完走し、
  出力にNaNやInfinityは認められなかった。
- UOSTケースでは境界条件ファイルがない旨の`W3IOBC`警告が1回表示される。
  公式回帰試験入力の構成によるもので、UOST計算は48時間完走している。

## GPU版との比較方針

CPU同一環境の再実行ではSHA-256の一致を一次確認に使える。GPU版は演算順序や
reductionの差でbitwise一致しない可能性が高いため、CSVの主要値とNetCDFフィールドを
絶対誤差・相対誤差で比較する。
