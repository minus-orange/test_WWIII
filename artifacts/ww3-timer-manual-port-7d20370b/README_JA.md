# WW3階層タイマー 手動移植用diff一式

## 目的

WAVEWATCH III 7.14の別source treeへ、`git apply`による一括patch適用ではなく、
diffを参照しながら階層タイマーを手作業で移植するための資料である。

```text
比較元: 948917a0b283ac383fb753fd304cf03cba3ffeb2
比較先: 7d20370b4cc23fb566b1efa63ba4875c15bb56a3
WW3 upstream: c3b0d04d0d632641dab2dde7f053f4ab3ee35043 (VERSION 7.14)
```

比較先には次の最終仕様を含む。

- `totalnoregion`を最外周とする最大4階層
- `WW3_ENABLE_TIMER`によるcompile時ON/OFF
- `mpi_f08`を使用
- MPI collectiveによるタイマー集約なし
- processごとのローカル集計
- `ww3_timer_rankNNNNNN.out`へのrank別出力

## ファイル構成

```text
.gitattributes
README_JA.md
SHA256SUMS
diffs/
  00-all-timer-changes.diff
  01-mod_timer-new-file.diff
  02-ww3_shel-instrumentation.diff
  03-w3wavemd-instrumentation.diff
  04-legacy-build-integration.diff
files/model/src/
  mod_timer.F90
```

`.gitattributes`は、diff内に保存された元sourceの末尾空白をGitの
whitespace検査対象から除外するためのartifact内設定である。diffそのものの内容は
変更せず、比較元から比較先への差分をそのまま保持している。

`00-all-timer-changes.diff`は全変更の統合版である。元環境との差異が大きい場合は、
`01`から`04`を順に参照して機能単位で移植する。

## 変更が必要なファイル

### 必須source

| ファイル | 変更内容 |
|---|---|
| `model/src/mod_timer.F90` | 新規タイマーmodule。完成版を`files/model/src/mod_timer.F90`にも格納 |
| `model/src/ww3_shel.F90` | 初期化、時間積分、終了処理と最外周`totalnoregion`の開始・停止 |
| `model/src/w3wavemd.F90` | `wave_model`、field更新、source項、伝播、出力の開始・停止 |

### WW3 legacy buildへ組み込む場合

| ファイル | 変更内容 |
|---|---|
| `model/bin/ad3.tmpl` | `WW3_EXTRA_CPP_FLAGS`をad3のpreprocessへ渡す |
| `model/bin/build_utils.sh` | `ww3_shel`の依存moduleへ`mod_timer`を追加 |
| `model/bin/make_makefile.sh` | `USE MOD_TIMER`を`mod_timer.o`依存関係へ変換 |
| `tools/build_nvhpc_legacy.sh` | ON/OFF、CPP/compiler flags、古い`.o/.mod`の自動無効化 |

独自build scriptを使う場合、`tools/build_nvhpc_legacy.sh`の移植は必須ではない。
ただし、次の条件を独自script側で満たす必要がある。

1. `mod_timer.F90`を`w3wavemd.F90`と`ww3_shel.F90`より先にcompileする。
2. `mod_timer.o`を`ww3_shel`のlink対象へ加える。
3. タイマー有効時はad3 preprocessとFortran compilerの両方へ
   `-DWW3_ENABLE_TIMER`を渡す。
4. タイマー無効時は両方から`-DWW3_ENABLE_TIMER`を除く。
5. タイマーsource変更後は古い`mod_timer.o`、`mod_timer.mod`、
   `w3wavemd.o`、`ww3_shel.o`を再利用しない。

## 推奨する手動移植順序

### 1. タイマーmoduleを配置

完成版を対象source treeへコピーする。

```bash
cp files/model/src/mod_timer.F90 /path/to/WW3/model/src/mod_timer.F90
```

`01-mod_timer-new-file.diff`は新規ファイル全体をdiff形式で確認するために使用する。

### 2. `ww3_shel.F90`へ大区分を移植

`02-ww3_shel-instrumentation.diff`を参照し、次を移植する。

- `USE MOD_TIMER`と`TIMER_FINALIZE_READY`
- `totalnoregion`
- `initialize`
- `data_structure_setup`
- `mpi_setup`
- `configuration_io`
- `model_initialize`
- `timestep_loop`
- `input_update`
- `data_assimilation`
- `finalize`、`final_barrier`、`final_report`
- 最後の`PRINT_TIMER()`

すべての追加は`#ifdef WW3_ENABLE_TIMER`で囲む。異常終了経路では未停止Regionを
出力しないよう、`TIMER_FINALIZE_READY`が真のときだけ終了タイマーを処理する。

### 3. `w3wavemd.F90`へ計算区分を移植

`03-w3wavemd-instrumentation.diff`を参照し、次を移植する。

- `USE MOD_TIMER`
- `wave_model`
- `field_updates`
- `source_terms_pre`
- `propagation`
- `source_terms`
- `output`

開始・停止は必ず同じ条件分岐の内側で対応させる。特に`source_terms_pre`はPDLIB、
`propagation`と`source_terms`は既存switch条件との位置関係をdiffで確認する。

### 4. build依存関係を移植

WW3標準legacy buildを使う場合は`04-legacy-build-integration.diff`を参照する。
対象側のbuild scriptが異なる場合は、上記5条件を同等の方法で実装する。

## diffの確認方法

個別表示:

```bash
less diffs/02-ww3_shel-instrumentation.diff
less diffs/03-w3wavemd-instrumentation.diff
less diffs/04-legacy-build-integration.diff
```

対象が比較元に近い場合のみ、適用可否を変更前に確認できる。

```bash
cd /path/to/WW3
git apply --check /path/to/diffs/00-all-timer-changes.diff
```

この確認に失敗しても、手動移植用資料としては使用できる。独自変更を上書きせず、
個別diffの`+`行を周囲の処理に合わせて転記する。

## buildと確認

本リポジトリのNVHPC legacy script相当の場合:

```bash
WW3_ENABLE_TIMER=ON ./tools/build_nvhpc_legacy.sh
```

実行後、MPI rankごとに次のファイルが作成される。

```text
ww3_timer_rank000000.out
ww3_timer_rank000001.out
...
```

確認例:

```bash
grep -A 30 WW3_PROFILE_BEGIN ww3_timer_rank000000.out
```

タイマーmoduleには`MPI_REDUCE`、`MPI_ALLREDUCE`、`MPI_COMM_SIZE`を含めない。
各processは自身の`count`と`elapsed_sec`だけを出力する。

## 移植後の静的確認

```bash
grep -n "USE MPI_F08" model/src/mod_timer.F90
grep -n "WW3_ENABLE_TIMER" model/src/ww3_shel.F90 model/src/w3wavemd.F90
grep -n "START_TIMER\|STOP_TIMER\|PRINT_TIMER" \
  model/src/ww3_shel.F90 model/src/w3wavemd.F90
```

`START_TIMER`と`STOP_TIMER`は実行経路ごとに対応している必要がある。
