# 配布用artifact

## `ww3-nvhpc-legacy-kit-e667fc9d.tar.gz`

別のWAVEWATCH III 7.14 source directoryへ、NVIDIA HPC SDKの非CMake
legacy build環境を移植するためのkitである。

```text
WW3 upstream commit : c3b0d04d0d632641dab2dde7f053f4ab3ee35043
kit source commit   : e667fc9d2930a113588d0f130f4e35f809c3f6a2
SHA-256             : 1cf5e76cc69faa3fc8dea295fba9f32a0a3900a183ef364be72b0975d81e9e25
```

WW3本体のCMake build用script、toolchain、patchは含まない。Linuxで警告や不要な
`._*`を発生させないPOSIX ustar形式である。依存ライブラリの
download/build script、`w3_setup`＋`w3_make`用NVHPC設定、ST4_UOST switch、
WW3 7.14用修正patch、smoke test、compiler別生成物切替script、SHRD/MPIの
実行ファイル別switchと6本限定ビルド処理、最外周`totalnoregion`を含む最大4階層の
`ww3_shel`タイマーを含む。
既知の旧NVHPC kitを導入済みのsource treeには、専用差分patchとsupport fileの
checksum照合により、安全な上書き更新を行う。

対象側で`w3gridmd.F90`または`ww3_sbs1.F90`が異なる場合、この2件の上流修正だけを
警告して省略し、NVHPC legacy build環境の導入は継続する。

使用方法:

```bash
tar -xzf artifacts/ww3-nvhpc-legacy-kit-e667fc9d.tar.gz
./ww3-nvhpc-legacy-kit-e667fc9d/install.sh /path/to/other/WW3
```

再生成方法:

```bash
git checkout e667fc9d2930a113588d0f130f4e35f809c3f6a2
./tools/export_nvhpc_build_kit.sh /tmp/ww3-nvhpc-legacy-kit-e667fc9d
```
