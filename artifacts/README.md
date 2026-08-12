# 配布用artifact

## `ww3-nvhpc-legacy-kit-e959cfbd.tar.gz`

別のWAVEWATCH III 7.14 source directoryへ、NVIDIA HPC SDKの非CMake
legacy build環境を移植するためのkitである。

```text
WW3 upstream commit : c3b0d04d0d632641dab2dde7f053f4ab3ee35043
kit source commit   : e959cfbd436a1a00652b0d4aafd350ba79d6802b
SHA-256             : f9934353bb1273e4b2651e5f072b1cf030b7e9fec50490ef471bbf3c34b54a05
```

WW3本体のCMake build用script、toolchain、patchは含まない。Linuxで警告や不要な
`._*`を発生させないPOSIX ustar形式である。依存ライブラリの
download/build script、`w3_setup`＋`w3_make`用NVHPC設定、ST4_UOST switch、
WW3 7.14用修正patch、smoke testを含む。

対象側で`w3gridmd.F90`または`ww3_sbs1.F90`が異なる場合、この2件の上流修正だけを
警告して省略し、NVHPC legacy build環境の導入は継続する。

使用方法:

```bash
tar -xzf artifacts/ww3-nvhpc-legacy-kit-e959cfbd.tar.gz
./ww3-nvhpc-legacy-kit-e959cfbd/install.sh /path/to/other/WW3
```

再生成方法:

```bash
git checkout e959cfbd436a1a00652b0d4aafd350ba79d6802b
./tools/export_nvhpc_build_kit.sh /tmp/ww3-nvhpc-legacy-kit-e959cfbd
```
