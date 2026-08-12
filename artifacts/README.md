# 配布用artifact

## `ww3-nvhpc-legacy-kit-52c6b817.tar.gz`

別のWAVEWATCH III 7.14 source directoryへ、NVIDIA HPC SDKの非CMake
legacy build環境を移植するためのkitである。

```text
WW3 upstream commit : c3b0d04d0d632641dab2dde7f053f4ab3ee35043
kit source commit   : 52c6b8178a1c4262bcc3e39f0bd0c807371e8431
SHA-256             : c5a3793642de08994366a497e7e148e5590cb2e7dcd47f2249b87e47de2d9cb1
```

WW3本体のCMake build用script、toolchain、patchは含まない。Linuxで警告や不要な
`._*`を発生させないPOSIX ustar形式である。依存ライブラリの
download/build script、`w3_setup`＋`w3_make`用NVHPC設定、ST4_UOST switch、
WW3 7.14用修正patch、smoke testを含む。

対象側で`w3gridmd.F90`または`ww3_sbs1.F90`が異なる場合、この2件の上流修正だけを
警告して省略し、NVHPC legacy build環境の導入は継続する。

使用方法:

```bash
tar -xzf artifacts/ww3-nvhpc-legacy-kit-52c6b817.tar.gz
./ww3-nvhpc-legacy-kit-52c6b817/install.sh /path/to/other/WW3
```

再生成方法:

```bash
git checkout 52c6b8178a1c4262bcc3e39f0bd0c807371e8431
./tools/export_nvhpc_build_kit.sh /tmp/ww3-nvhpc-legacy-kit-52c6b817
```
