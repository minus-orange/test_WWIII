# NVHPC版 `ww3_shel` 階層タイマー

## 概要

NVHPCのCMake不使用legacy buildで、`ww3_shel`の全体時間、初期化、時間積分、終了処理と、
`W3WAVE`内の主要処理時間を測定する。タイマー呼び出しは`WW3_ENABLE_TIMER`の
プリプロセッサ定義で切り替わり、無効時は計測コード自体が実行ファイルへ入らない。

タイマー実装は次のファイルを基にWW3向けへ移植した。

- 取得元: [`mod_timer.f90`](https://github.com/minus-orange/test_tddft/blob/tddft-openacc-residency/FPSEID21/tddft_2022October/mod_timer.f90)
- 取得元revision: `2e9c92b3c2391832b7d0137b201486c394bcd630`
- 取込先: `model/src/mod_timer.F90`

FPSEID固有の外部wrapperと診断出力は除き、`reset_timer`、`start_timer`、
`stop_timer`、`print_timer`を使用する。MPI collectiveによるrank間集約は行わず、
各processが自身の呼出し回数と経過時間を`MPI_FINALIZE`より前にrank別ファイルへ出力する。

## ビルド時の有効・無効

`tools/build_nvhpc_legacy.sh`では既定で有効である。

```bash
./tools/build_nvhpc_legacy.sh
```

明示的に有効化する場合:

```bash
WW3_ENABLE_TIMER=ON ./tools/build_nvhpc_legacy.sh
```

無効化する場合:

```bash
WW3_ENABLE_TIMER=OFF ./tools/build_nvhpc_legacy.sh
```

scriptは有効時だけ`-DWW3_ENABLE_TIMER`を`WW3_EXTRA_CPP_FLAGS`と
`EXTRA_COMP_OPTIONS`へ追加する。前者は`ad3`のsource生成時、後者はcompiler実行時に
同じ`ifdef`を有効にする。
前回とモードが変わった場合、またはタイマー関連sourceが更新された場合は、legacy
Makefileが古いobjectを再利用しないよう、`mod_timer`、`w3wavemd`、`ww3_shel`だけを
再コンパイルする。

## 計測階層

最大ネスト数は`mod_timer.F90`でも4に制限している。現在の計測木は次のとおり。

```text
totalnoregion
  +- initialize
       +- data_structure_setup
       +- mpi_setup
       +- configuration_io
       +- model_initialize
  +- timestep_loop
       +- input_update
       +- wave_model
            +- field_updates
            +- source_terms_pre
            +- propagation
            +- source_terms
            +- output
       +- data_assimilation
  +- finalize
       +- final_barrier
       +- final_report
```

`totalnoregion`はタイマー初期化直後から`finalize`終了直後までを囲む最外周Regionで、
初期化・時間積分・終了表示を含むプログラム主要処理全体の経過時間を表す。

`source_terms_pre`は主にPDLIBの分割source項前半、`source_terms`は通常の
`W3SRCE`を含むsource項計算、`propagation`はスペクトル内・空間伝播、`output`は
格子・点・restart等の出力処理を表す。タイマー呼び出しはOpenMP並列ループの外側に
置いているため、計測moduleを複数threadから同時更新しない。

## 出力確認

正常終了時は、MPI rankごとに次のファイルを作成する。

```text
ww3_timer_rank000000.out
ww3_timer_rank000001.out
ww3_timer_rank000002.out
...
```

各ファイルには、そのrankだけの呼出し木とprocess-local集計が出る。

```text
[WW3 Timer Output]
MPI rank: 0
...
 WW3_PROFILE_BEGIN
 rank  id label                    count        elapsed_sec
...
 WW3_PROFILE_END
```

`elapsed_sec`はファイル名で示されるrank自身のinclusive timeである。rank間の最大値や
平均値が必要な場合は、実行後にこれらのファイルを別途集計する。タイマー出力処理には
`MPI_ALLREDUCE`、`MPI_REDUCE`、barrier等を追加しない。初期化途中の入力エラー等で
終了した場合は、未完了区間を誤って記録しないためタイマーファイルを出力しない。

## 計測上の注意

- 各区間はinclusive timeであり、親区間は子区間を含む。
- `TOTAL (inclusive regions)`は親子を重複加算した表示で、実行全体時間ではない。
- `totalnoregion`と`finalize`は、rank番号を取得してファイル出力する必要があるため、
  `MPI_FINALIZE`そのものと、その後に実行される処理は含まない。
- rank別ファイルは同名を`STATUS='REPLACE'`で開くため、同じdirectoryで再実行すると
  前回結果を上書きする。保存が必要な場合は実行ごとにdirectoryを分ける。
- 計測のON/OFFを比較する場合は、同じswitch、MPI rank数、入力、GPU、実行条件を使う。
- `W3_SEC1`は今回の`switch_ST4_UOST`に含まれない。別switchへ展開する場合は、
  sub-second loopとタイマー開始・終了の対応を再確認する。
