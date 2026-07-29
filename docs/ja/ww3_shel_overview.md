# `ww3_shel`処理概要

## 役割

`ww3_shel`は、事前作成された外力ファイルを使用して単一格子の
WAVEWATCH III計算を実行するドライバーです。波浪の伝播と物理過程を
直接実装するプログラムではなく、入力、初期化、時間管理、`W3WAVE`の呼出し、
出力、MPI終了処理を統括します。

多重格子計算には`ww3_multi`を使用します。

## 全体フロー

```text
MPI・内部データ構造初期化
  → ww3_shel.nml / ww3_shel.inp読込み
  → mod_def.ww3・restart.ww3読込み
  → 外力の現在時刻・次時刻データ読込み
  → 次の外力更新時刻または出力時刻を決定
  → W3WAVEでその時刻まで積分
  → 出力・リスタート作成
  → 終了時刻まで反復
  → MPI終了
```

プログラム本体は
[`PROGRAM W3SHEL`](../../model/src/ww3_shel.F90#L16)から始まります。
ソース内にも処理構造の説明があります
（[`ww3_shel.F90`](../../model/src/ww3_shel.F90#L188)）。

## 1. データ構造とMPIの初期化

最初に格子、波浪場、補助データ、出力、入力用の内部データ構造を作成し、
対象モデル番号1を選択します。

```fortran
CALL W3NMOD ( 1, 6, 6 )
CALL W3NDAT (    6, 6 )
CALL W3NAUX (    6, 6 )
CALL W3NOUT (    6, 6 )
CALL W3NINP (    6, 6 )
```

実装: [`ww3_shel.F90`](../../model/src/ww3_shel.F90#L445)

今回のswitchには`DIST MPI`が含まれるため、`MPI_INIT`、プロセス数、
ランクの取得を行います。

- MPI初期化: [`ww3_shel.F90`](../../model/src/ww3_shel.F90#L481)
- MPIサイズ・ランク: [`ww3_shel.F90`](../../model/src/ww3_shel.F90#L496)

## 2. 計算条件と出力条件の読込み

Namelist形式では`W3NMLSHEL`が`ww3_shel.nml`を読み込みます。

- 実装: [`ww3_shel.F90`](../../model/src/ww3_shel.F90#L695)

主な設定内容は次のとおりです。

- 計算開始・終了時刻
- 水位、海流、風、海氷などの入力種別
- 外力ファイルの更新時刻
- 格子、地点、トラック、リスタート、境界、分離波系の出力時刻
- 出力項目と出力先

旧形式の`ww3_shel.inp`もサポートされています。

## 3. モデル初期化

`W3INIT`を呼び、格子、波浪スペクトル、MPI分割、出力用配列を準備します。

```fortran
CALL W3INIT ( 1, .FALSE., 'ww3', NDS, NTRACE, ODAT, ... )
```

- 呼出し元: [`ww3_shel.F90`](../../model/src/ww3_shel.F90#L1946)
- `W3INIT`本体: [`w3initmd.F90`](../../model/src/w3initmd.F90#L163)
- `mod_def.ww3`読込み: [`w3initmd.F90`](../../model/src/w3initmd.F90#L735)
- `restart.ww3`読込み: [`w3initmd.F90`](../../model/src/w3initmd.F90#L978)

`restart.ww3`の内容により、理想化cold start、風によるcold start、
calm start、full restartを判定します。

## 4. 外力更新ループ

入力外力がある場合、終了時刻まで次のループを実行します。

```fortran
DO WHILE ( DTTST .GT. 0.)
    ! 必要な外力をW3FLDGなどで更新
    TIME0 = TTIME
    CALL W3WAVE ( 1, ODAT, TIME0 )
END DO
```

- 時間ループ: [`ww3_shel.F90`](../../model/src/ww3_shel.F90#L2045)
- `W3WAVE`呼出し: [`ww3_shel.F90`](../../model/src/ww3_shel.F90#L2584)

`ww3_shel`は、終了時刻だけでなく次の外力更新時刻や出力時刻も考慮して
`W3WAVE`の積分終了時刻を決めます。このため、外力更新間隔とモデル内部の
時間刻みは別の概念です。

## 5. `W3WAVE`の処理

`W3WAVE`は指定された終了時刻まで波作用量スペクトルを積分します。

- 本体: [`w3wavemd.F90`](../../model/src/w3wavemd.F90#L229)
- ソース内の処理構造: [`w3wavemd.F90`](../../model/src/w3wavemd.F90#L355)

主な順序は次のとおりです。

1. 海流と風を現在時刻へ補間
2. 境界条件、海氷、水位、wet/dry状態を更新
3. スペクトル内伝播
4. 水平空間伝播
5. ソース項の計算と積分
6. モデル時刻の更新
7. 必要な出力の作成

今回の`PR3 UQ`構成では、スペクトル内伝播に`W3KTP3`、規則格子の
水平伝播に`W3XYP3`が選択されます。

- `W3KTP3`: [`w3wavemd.F90`](../../model/src/w3wavemd.F90#L1858)
- `W3XYP3`: [`w3wavemd.F90`](../../model/src/w3wavemd.F90#L1991)

各海点のソース項は`W3SRCE`で計算します。

- 呼出し: [`w3wavemd.F90`](../../model/src/w3wavemd.F90#L2311)
- 本体: [`w3srcemd.F90`](../../model/src/w3srcemd.F90#L190)

今回有効な主要処理は次のとおりです。

| switch | ルーチン | 概要 |
|---|---|---|
| `LN1` | `W3SLN1` | 線形風入力 |
| `ST4` | `W3SIN4`, `W3SDS4` | 風入力と飽和度ベース散逸 |
| `NL1` | `W3SNL1` | DIAによる4波非線形相互作用 |
| `BT1` | `W3SBT1` | JONSWAP型海底摩擦 |
| `UOST` | `UOST_SRCTRMCOMPUTE` | 未解像障害物による減衰・遮蔽 |
| `IS1` | `W3SIS1` | 海氷による保守的散乱 |
| `IC0` | なし | 海氷散逸モデルを使用しない |

対応する実装:

- `W3SIN4`: [`w3srcemd.F90`](../../model/src/w3srcemd.F90#L1239)
- `W3SNL1`: [`w3srcemd.F90`](../../model/src/w3srcemd.F90#L1260)
- `W3SDS4`: [`w3srcemd.F90`](../../model/src/w3srcemd.F90#L1303)
- `W3SBT1`: [`w3srcemd.F90`](../../model/src/w3srcemd.F90#L1339)
- UOST: [`w3srcemd.F90`](../../model/src/w3srcemd.F90#L1361)
- `W3SIS1`: [`w3srcemd.F90`](../../model/src/w3srcemd.F90#L1388)

## 6. 出力と終了

出力時刻では、`W3OUTG`が波浪スペクトルから格子出力値を生成し、
用途別のI/Oルーチンがファイルへ書き込みます。

- 格子出力値生成: [`w3wavemd.F90`](../../model/src/w3wavemd.F90#L2490)
- 格子出力: [`w3wavemd.F90`](../../model/src/w3wavemd.F90#L2656)
- 地点出力: [`w3wavemd.F90`](../../model/src/w3wavemd.F90#L2694)
- リスタート出力: [`w3wavemd.F90`](../../model/src/w3wavemd.F90#L2708)

終了時刻に達すると`FINALISE`を呼び、初期化時間と総経過時間を表示して
`MPI_FINALIZE`を実行します。

- 終了処理呼出し: [`ww3_shel.F90`](../../model/src/ww3_shel.F90#L2645)

## 入出力関係

| 区分 | 代表ファイル | 作成・利用 |
|---|---|---|
| モデル定義 | `mod_def.ww3` | `ww3_grid`が作成、`W3INIT`が読込み |
| 初期状態 | `restart.ww3` | `ww3_strt`または以前の計算が作成 |
| 外力 | `wind.ww3`, `current.ww3`, `level.ww3`, `ice.ww3` | 主に`ww3_prnc`が作成 |
| 計算制御 | `ww3_shel.nml`または`ww3_shel.inp` | `ww3_shel`が読込み |
| 格子生出力 | `out_grd.ww3` | `ww3_shel`が作成 |
| 地点生出力 | `out_pnt.ww3` | `ww3_shel`が作成 |
| 再開データ | `restart*.ww3` | `ww3_shel`が作成 |

NetCDFへの変換には、通常`ww3_ounf`または`ww3_ounp`を使用します。
