# 日本語ドキュメント

このディレクトリには、本リポジトリで確認した `ST4_UOST` 構成と
`ww3_shel` の解析結果をまとめています。

## ドキュメント一覧

| 文書 | 内容 |
|---|---|
| [ww3_shel処理概要](ww3_shel_overview.md) | `ww3_shel`から`W3INIT`、`W3WAVE`、`W3SRCE`へ至る処理フロー |
| [ST4_UOST switch仕様](switch_ST4_UOST.md) | 使用switch、主要物理過程、コンパイル時の選択内容 |
| [ビルド手順と確認結果](build_ST4_UOST.md) | macOS arm64で再現可能なCMakeビルド手順と生成LM |
| [実行準備チェックリスト](run_preparation.md) | `ww3_grid`から計算・後処理までに必要な入力と確認事項 |
| [CPU基準テスト](cpu_baseline_tests.md) | 小規模な伝播、ST4ソース項、UOSTのCPU実行結果と再実行手順 |
| [NVIDIA HPC SDKビルド環境](build_NVHPC.md) | `nvfortran`とNVHPC版MPI/NetCDFを使う標準CMakeビルド手順 |
| [NVIDIA HPC SDK legacy build](build_NVHPC_legacy.md) | CMakeを使わない`w3_setup`＋`w3_make`手順 |
| [Intel oneAPI legacy build](build_ONEAPI_legacy.md) | `ifx`／Intel MPIによるCMakeなしWW3本体ビルド手順 |
| [NVHPC版UOSTスモークテスト](nvhpc_smoke_test.md) | 作成済みLMによる小規模実行と結果検査script |
| [NVHPC移植用ビルドキット](nvhpc_build_kit.md) | 別のWW3 7.14 source directoryへ非CMakeのNVHPC legacy build環境を移植する手順 |

## 対象

- 上流リポジトリ: `NOAA-EMC/WW3`
- 取り込み元コミット: `c3b0d04d0d632641dab2dde7f053f4ab3ee35043`
- switchファイル:
  [`model/bin/switch_ST4_UOST`](../../model/bin/switch_ST4_UOST)
- ビルド確認日: 2026-07-29

## 注意

switchはコンパイル時に使用する物理過程・並列化・入出力機能を選択します。
計算格子、周波数・方向分割、時間刻み、物理定数はswitchだけでは決まりません。
これらは主に`ww3_grid`の入力と、そこから生成される`mod_def.ww3`で定義します。

## プロジェクトの制限事項

対象計算機からこのプロジェクトへのデータ入力は、画面を撮影した写真、または
短いテキストに限られる。大容量のlog、計算結果ファイル、NetCDFなどを直接受け取って
解析することは前提としない。このため、実行・検査scriptは端末画面の写真1枚または
短い貼り付けで判断できるよう、最終判定と主要値を簡潔に表示する。
