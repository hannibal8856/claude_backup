#!/bin/bash
# 列出 dl/ 底下所有 Rust application(BIN crate),
# 若 dl 端有 Cargo.lock,比對 output/build 端是否被 cargo 更新過(增量解析),
# 不一致時輸出警告。
#
# 用法: check_rust_app_lock.sh [buildroot路徑]
#   預設 buildroot = ~/NOS_v6.0_develop/buildroot

BUILDROOT="${1:-$HOME/NOS_v6.0_develop/buildroot}"
DL="$BUILDROOT/dl"
OB="$BUILDROOT/output/build"

[ -d "$DL" ] || { echo "找不到 $DL"; exit 1; }

warn=0
apps=0

# 找出所有 BIN crate:有 src/main.rs、src/bin/ 或 Cargo.toml 內有 [[bin]]
while read -r toml; do
    dir=$(dirname "$toml")
    if [ -f "$dir/src/main.rs" ] || [ -d "$dir/src/bin" ] || grep -q '^\[\[bin\]\]' "$toml"; then
        apps=$((apps+1))
        rel=${dir#"$DL"/}                       # 例: plugin_moxa_firmware_update/app
        repo=${rel%%/*}                         # 例: plugin_moxa_firmware_update
        sub=${rel#"$repo"}                      # 例: /app(無子目錄時為空)
        dl_lock="$dir/Cargo.lock"
        ob_lock="$OB/${repo}-custom${sub}/Cargo.lock"

        if [ ! -f "$dl_lock" ]; then
            printf "%-70s (dl 無 Cargo.lock,跳過比對)\n" "$rel"
            continue
        fi
        if [ ! -f "$ob_lock" ]; then
            printf "%-70s (output/build 無 lock,尚未 build)\n" "$rel"
            continue
        fi
        if cmp -s "$dl_lock" "$ob_lock"; then
            printf "%-70s OK\n" "$rel"
        else
            added=$(diff "$dl_lock" "$ob_lock" | grep -c '^> name = ')
            removed=$(diff "$dl_lock" "$ob_lock" | grep -c '^< name = ')
            printf "%-70s ⚠ 警告: build 端 lock 已被更新(多 %s pkg / 少 %s pkg)→ 建議同步回 dl 並 commit\n" \
                   "$rel" "$added" "$removed"
            warn=$((warn+1))
        fi
    fi
done < <(find "$DL" -maxdepth 4 -name Cargo.toml -not -path '*/target/*' 2>/dev/null | sort)

# workspace 型(如 rust_moxa_build):bin 的 lock 在 workspace root,而非 bin 目錄
while read -r toml; do
    grep -q '^\[workspace\]' "$toml" || continue
    dir=$(dirname "$toml")
    rel=${dir#"$DL"/}
    dl_lock="$dir/Cargo.lock"
    ob_lock="$OB/${rel}-custom/Cargo.lock"
    [ -f "$dl_lock" ] || continue
    if [ ! -f "$ob_lock" ]; then
        printf "%-70s (output/build 無 lock,尚未 build)\n" "$rel [workspace]"
    elif cmp -s "$dl_lock" "$ob_lock"; then
        printf "%-70s OK\n" "$rel [workspace]"
    else
        added=$(diff "$dl_lock" "$ob_lock" | grep -c '^> name = ')
        removed=$(diff "$dl_lock" "$ob_lock" | grep -c '^< name = ')
        printf "%-70s ⚠ 警告: build 端 lock 已被更新(多 %s pkg / 少 %s pkg)→ 建議同步回 dl 並 commit\n" \
               "$rel [workspace]" "$added" "$removed"
        warn=$((warn+1))
    fi
done < <(find "$DL" -maxdepth 2 -name Cargo.toml -not -path '*/target/*' 2>/dev/null | sort)

echo "-----------------------------------------------------------------------"
echo "Rust app 共 $apps 個;lock 不同步警告: $warn 個"
exit $((warn > 0))
