# 配布用artifact

## `ww3-nvhpc-legacy-kit-7d20370b.tar.gz`

別のWAVEWATCH III 7.14 source directoryへ、NVIDIA HPC SDKの非CMake
legacy build環境を移植するためのkitである。

```text
WW3 upstream commit : c3b0d04d0d632641dab2dde7f053f4ab3ee35043
kit source commit   : 7d20370b4cc23fb566b1efa63ba4875c15bb56a3
SHA-256             : 98008dfb863f017dcda26e7937402ce19038a66ad16f09eb2d8f4ef7993b0758
```

WW3本体のCMake build用script、toolchain、patchは含まない。Linuxで警告や不要な
`._*`を発生させないPOSIX ustar形式である。依存ライブラリの
download/build script、`w3_setup`＋`w3_make`用NVHPC設定、ST4_UOST switch、
WW3 7.14用修正patch、smoke test、compiler別生成物切替script、SHRD/MPIの
実行ファイル別switchと6本限定ビルド処理、最外周`totalnoregion`を含み、MPI collectiveを
使わずrank別ファイルへ出力する最大4階層の`ww3_shel`タイマーを含む。
既知の旧NVHPC kitを導入済みのsource treeには、専用差分patchとsupport fileの
checksum照合により、安全な上書き更新を行う。

対象側で`w3gridmd.F90`または`ww3_sbs1.F90`が異なる場合、この2件の上流修正だけを
警告して省略し、NVHPC legacy build環境の導入は継続する。

使用方法:

```bash
tar -xzf artifacts/ww3-nvhpc-legacy-kit-7d20370b.tar.gz
./ww3-nvhpc-legacy-kit-7d20370b/install.sh /path/to/other/WW3
```

再生成方法:

```bash
git checkout 7d20370b4cc23fb566b1efa63ba4875c15bb56a3
./tools/export_nvhpc_build_kit.sh /tmp/ww3-nvhpc-legacy-kit-7d20370b
```

## タイマー手動移植用diff

`ww3-timer-manual-port-7d20370b.tar.gz`は、既存sourceへの一括patch適用が難しい場合に、
タイマー関連変更だけを手作業で移植するための資料である。

```text
SHA-256: a82be1a119e24947c363aa7bcf529628cf56f7eb1919a191223e4df6e15496f5
```

統合diff、必須source別diff、legacy build連携diff、完成版`mod_timer.F90`、日本語の
移植手順とchecksumを含む。

```bash
tar -xzf artifacts/ww3-timer-manual-port-7d20370b.tar.gz
less ww3-timer-manual-port-7d20370b/README_JA.md
```
