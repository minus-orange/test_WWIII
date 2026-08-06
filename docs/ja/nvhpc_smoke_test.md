# NVHPC版UOSTスモークテスト

## 目的

NVIDIA HPC SDKで作成した`ST4_UOST`構成の実行ファイルを再コンパイルせずに使い、
小規模な公式回帰ケースで実行時の正常性を確認する。対象は
`regtests/ww3_ts4/input_rg_shel`の13×12格子、48時間計算である。

## 実行

NVHPCとMPIのmodule、およびビルドしたNetCDF/HDF5の実行環境を設定したshellで実行する。

```bash
module load hpc_sdk/nvhpc/26.3
./tools/run_nvhpc_uost_test.sh
```

既定では`build-nvhpc/bin`の実行ファイルを使用し、1 MPI process、
`OMP_NUM_THREADS=1`で次を順番に実行する。HPC-Xの移設されたruntime pathを
正しく初期化するため、前処理・後処理を含む全programを同じ`mpirun`経由で起動する。

```text
ww3_grid → ww3_strt → ww3_shel → ww3_ounf
```

各実行結果は既存結果を上書きせず、
`regtests/ww3_ts4/work_nvhpc_uost_<UTC日時>_<PID>`へ保存する。

実行ファイルやMPI process数を変更する場合:

```bash
WW3_BIN_DIR=/path/to/build-nvhpc/bin \
WW3_TEST_NPROC=2 \
./tools/run_nvhpc_uost_test.sh
```

MPI launcherが`mpirun`以外の場合は、コマンド名または絶対パスを指定する。

```bash
WW3_MPIEXEC=mpiexec ./tools/run_nvhpc_uost_test.sh
```

`SHRD`構成のLMをMPI launcherなしで確認する場合だけ、`WW3_MPIEXEC=none`を指定する。
今回の`DIST MPI`構成では既定の`mpirun`を使用する。

## HPC-Xの`MPI_Init`エラー

`ww3_strt`などを直接起動すると、HPC-Xがbuild時の
`/proj/nv/libraries/.../share/openmpi`を参照し、`help-opal-runtime.txt`を開けずに
`MPI_Init`で停止する場合がある。これはWW3入力データのエラーではなく、HPC-Xの
runtime初期化経路の問題である。本scriptは全programを`mpirun`から起動して回避する。

再実行前に、コンパイル時と同じmoduleのlauncherが選択されていることを確認する。

```bash
module load hpc_sdk/nvhpc/26.3
which mpirun
mpirun --version
./tools/run_nvhpc_uost_test.sh
```

過去の失敗結果は上書きせず残る。新しい実行では別のwork directoryが自動作成されるため、
失敗directoryを削除する必要はない。

## 結果確認

実行scriptが最後に表示したwork directoryを指定する。

```bash
./tools/check_nvhpc_uost_test.sh \
  regtests/ww3_ts4/work_nvhpc_uost_<UTC日時>_<PID>
```

引数を省略すると、同じリポジトリ内で最後に更新されたNVHPC UOST結果を確認する。

```bash
./tools/check_nvhpc_uost_test.sh
```

確認内容:

- 4 programの終了コードと`End of program`
- `mod_def.ww3`、restart、格子・地点出力、NetCDF出力の存在
- log中のfatal error、NaN、Infinity、MPI abort
- NetCDFの49時刻×12緯度×13経度と`hs`変数
- NetCDF metadataに`ST4`と`UOST`が記録されていること
- 全時刻の有義波高が有限で0～64 mの範囲にあること
- 主要出力のSHA-256

検査結果はwork directoryの`result-summary.txt`、ハッシュ値は
`result-sha256sums.txt`へ保存する。初回CPU実行のこれらを保存しておけば、
OpenACC版との比較対象として利用できる。GPU版は演算順序が変わり得るため、
SHA-256不一致だけで異常と判断せず、次段階で数値許容誤差による比較を行う。

UOSTの格子幅に関する警告と、境界入力がないことを示す`W3IOBC`警告は、
この公式回帰ケースで想定される警告である。

## 結果の共有方法

対象計算機から共有できるデータは、画面を撮影した写真または短いテキストに限られる。
結果確認scriptの末尾に表示される`RESULT: PASS`または`RESULT: FAIL`までを写真で共有する。
失敗時にテキストで共有する場合は、`FAIL:`で始まる行と、該当programの`.out`末尾を
20～30行程度に絞る。大容量logやNetCDFファイルの直接共有は前提としない。
各検査の詳細は`result-summary.txt`へ保存され、端末には波高要約、成功・失敗数、
最終判定だけが表示される。

```bash
test_result_dir=regtests/ww3_ts4/work_nvhpc_uost_20260806T150000Z_12345
tail -n 30 "${test_result_dir}/ww3_shel.out"
```
