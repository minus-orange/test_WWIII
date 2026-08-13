# `switch_ST4_UOST`仕様

## switch文字列

使用ファイル:
[`model/bin/switch_ST4_UOST`](../../model/bin/switch_ST4_UOST)

```text
UOST NOPA PR3 UQ FLX0 LN1 ST4 NL1 BT1 IC0 IS1 REF0 DB0 MLIM TR0 BS0 XX0 WNX1 WNT1 CRX1 CRT1 LRB4 O0 O1 O2 O3 O4 O5 O6 O7 O11 MLIM F90 NOGRB NC4 DIST MPI
```

元資料に合わせて`MLIM`が2回記載されています。CMakeのswitch検証では
同じ選択肢として扱われ、2026-07-29のビルドでは問題になりませんでした。

## 主要な選択

| 分類 | switch | 意味 |
|---|---|---|
| 並列化 | `DIST MPI` | MPI分散メモリ並列 |
| 伝播 | `PR3 UQ` | 第三次精度UQ伝播 |
| 風入力・散逸 | `ST4` | Ardhuin系ST4パッケージ |
| 線形入力 | `LN1` | 線形風入力項 |
| 非線形相互作用 | `NL1` | DIAによる4波相互作用 |
| 海底摩擦 | `BT1` | JONSWAP型海底摩擦 |
| 海氷散逸 | `IC0` | 海氷散逸なし |
| 海氷散乱 | `IS1` | 簡易な海氷散乱 |
| 未解像障害物 | `UOST` | 未解像障害物ソース項 |
| 反射 | `REF0` | 海岸・障害物反射なし |
| NetCDF | `NC4` | NetCDF-4対応 |
| GRIB | `NOGRB` | GRIBライブラリを使用しない |

`UOST`は格子より小さい障害物の影響を、局所透過率とshadow透過率を使って
スペクトルの減衰・遮蔽として表現します。実行時には格子設定に応じて
`obstructions_local.<gridname>.in`および
`obstructions_shadow.<gridname>.in`が必要になります。

## コンパイルで確認された定義

CMakeはこのswitchを次のようなプリプロセッサ定義へ変換します。

```text
W3_UOST W3_PR3 W3_UQ W3_LN1 W3_ST4 W3_NL1 W3_BT1
W3_IC0 W3_IS1 W3_REF0 W3_NC4 W3_DIST W3_MPI ...
```

## 実行ファイル別のswitch

計算本体`ww3_shel`は従来のMPI版`switch_ST4_UOST`を使用する。前処理・後処理の
5本には、同じ物理・入出力機能から`DIST MPI`を除き`SHRD`へ置換した
[`model/bin/switch_ST4_UOST_SHRD`](../../model/bin/switch_ST4_UOST_SHRD)を使用する。

```text
UOST NOPA PR3 UQ FLX0 LN1 ST4 NL1 BT1 IC0 IS1 REF0 DB0 MLIM TR0 BS0 XX0 WNX1 WNT1 CRX1 CRT1 LRB4 O0 O1 O2 O3 O4 O5 O6 O7 O11 MLIM F90 NOGRB NC4 SHRD
```

NVHPC版とoneAPI版の両方で、次の同じ6本を作成する。

| 実行ファイル | switch | MPI |
|---|---|---|
| `ww3_grid` | `ST4_UOST_SHRD` | なし |
| `ww3_strt` | `ST4_UOST_SHRD` | なし |
| `ww3_prnc` | `ST4_UOST_SHRD` | なし |
| `ww3_shel` | `ST4_UOST` | あり |
| `ww3_ounf` | `ST4_UOST_SHRD` | なし |
| `ww3_ounp` | `ST4_UOST_SHRD` | なし |

元のswitchに`PDLIB`は含まれないため、`ww3_prnc`のSHRD版にも`PDLIB`は入らない。
`force_pdlib=1`に相当する別構成からswitchを作る場合も`PDLIB`を除く。

実際のビルド定義は、ビルド後の
`build/model/src/CMakeFiles/ww3_lib.dir/flags.make`で確認できます。
`build`ディレクトリは生成物のためGit管理対象外です。

## switchに含まれない計算条件

以下はこのファイルだけでは決まりません。

- 全球・領域計算の別
- 水平解像度と格子点数
- 周波数分割数`NK`
- 方位分割数`NTH`
- 全体・伝播・ソース項の時間刻み
- ST4、NL1、BT1、UOSTなどの係数
- 出力項目と出力間隔

これらは主に`ww3_grid.nml`／`ww3_grid.inp`、`ww3_shel.nml`、
各物理過程のnamelistで設定され、`mod_def.ww3`に反映されます。

## 関連マニュアル

- ST4: [`manual/eqs/ST4.tex`](../../manual/eqs/ST4.tex)
- NL1: [`manual/eqs/NL1.tex`](../../manual/eqs/NL1.tex)
- BT1: [`manual/eqs/BT1.tex`](../../manual/eqs/BT1.tex)
- IS1: [`manual/eqs/IS1.tex`](../../manual/eqs/IS1.tex)
- UOST: [`manual/eqs/UOST.tex`](../../manual/eqs/UOST.tex)
