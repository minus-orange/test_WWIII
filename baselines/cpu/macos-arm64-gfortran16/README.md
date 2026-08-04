# macOS arm64 / GNU Fortran 16 CPU baseline

2026-08-04に生成したWAVEWATCH III 7.14のCPU基準結果である。

## 収録内容

- `key_results.csv`: 伝播テストの中心点とST4の6時間ごとの主要波浪諸元
- `uost_final_hs.csv`: UOSTテスト終了時刻の有義波高フィールド
- `sha256sums.txt`: 入力と主要出力のSHA-256

`uost_final_hs.csv`は`2000-01-03T00:00:00Z`の`hs` [m]である。`NA`はNetCDFの
`_FillValue`に対応する。

バイナリのWW3ネイティブ出力とNetCDFはGitに登録せず、`regtests/*/work*`下に
再生成する。これによりリポジトリサイズを抑えつつ、入力ハッシュ、出力ハッシュ、
主要数値を比較可能にしている。

再生成手順と警告の扱いは
[`docs/ja/cpu_baseline_tests.md`](../../../docs/ja/cpu_baseline_tests.md)を参照する。
