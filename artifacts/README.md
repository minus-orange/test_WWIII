# 配布用artifact

## `ww3-nvhpc-legacy-kit-7b149b10.tar.gz`

別のWAVEWATCH III 7.14 source directoryへ、NVIDIA HPC SDKの非CMake
legacy build環境を移植するためのkitである。

```text
WW3 upstream commit : c3b0d04d0d632641dab2dde7f053f4ab3ee35043
kit source commit   : 7b149b107dbd4353c0f3e6f506c4b90e72861924
SHA-256             : 8782964b21f10c0a73277a34189e73848eadb5f058bceb894cec53efb71322e7
```

WW3本体のCMake build用script、toolchain、patchは含まない。依存ライブラリの
download/build script、`w3_setup`＋`w3_make`用NVHPC設定、ST4_UOST switch、
WW3 7.14用修正patch、smoke testを含む。

使用方法:

```bash
tar -xzf artifacts/ww3-nvhpc-legacy-kit-7b149b10.tar.gz
./ww3-nvhpc-legacy-kit-7b149b10/install.sh /path/to/other/WW3
```

再生成方法:

```bash
git checkout 7b149b107dbd4353c0f3e6f506c4b90e72861924
./tools/export_nvhpc_build_kit.sh /tmp/ww3-nvhpc-legacy-kit-7b149b10
```
