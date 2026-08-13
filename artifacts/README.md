# 配布用artifact

## `ww3-nvhpc-legacy-kit-cfdb8daf.tar.gz`

別のWAVEWATCH III 7.14 source directoryへ、NVIDIA HPC SDKの非CMake
legacy build環境を移植するためのkitである。

```text
WW3 upstream commit : c3b0d04d0d632641dab2dde7f053f4ab3ee35043
kit source commit   : cfdb8daf2aa21aa32bac1bbd9395c67287492385
SHA-256             : 27d551aa2fa9a5a61fdad652d711081b89db9ca5b7d67f2cccba126cc9863926
```

WW3本体のCMake build用script、toolchain、patchは含まない。Linuxで警告や不要な
`._*`を発生させないPOSIX ustar形式である。依存ライブラリの
download/build script、`w3_setup`＋`w3_make`用NVHPC設定、ST4_UOST switch、
WW3 7.14用修正patch、smoke test、compiler別生成物切替scriptを含む。

対象側で`w3gridmd.F90`または`ww3_sbs1.F90`が異なる場合、この2件の上流修正だけを
警告して省略し、NVHPC legacy build環境の導入は継続する。

使用方法:

```bash
tar -xzf artifacts/ww3-nvhpc-legacy-kit-cfdb8daf.tar.gz
./ww3-nvhpc-legacy-kit-cfdb8daf/install.sh /path/to/other/WW3
```

再生成方法:

```bash
git checkout cfdb8daf2aa21aa32bac1bbd9395c67287492385
./tools/export_nvhpc_build_kit.sh /tmp/ww3-nvhpc-legacy-kit-cfdb8daf
```
