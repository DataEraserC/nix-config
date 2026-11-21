#!/usr/bin/env bash
set -euo pipefail

# 检查 pass 密码库中是否存在重复密码。
# 用法：
#   ./pass-duplicate-check.sh [pass目录]
# 示例：
#   ./pass-duplicate-check.sh xxx
#   ./pass-duplicate-check.sh xxx/Account1
#
# pass 条目格式示例：
#   第一行：密码
#   username:用户名
#   email:邮箱

PASS_PREFIX="${1:-}"
PASSWORD_STORE_DIR="${PASSWORD_STORE_DIR:-$HOME/.password-store}"

if ! command -v pass >/dev/null 2>&1; then
    echo "错误：未找到 pass 命令。" >&2
    exit 2
fi

if [[ ! -d "$PASSWORD_STORE_DIR" ]]; then
    echo "错误：密码库目录不存在：$PASSWORD_STORE_DIR" >&2
    exit 2
fi

search_dir="$PASSWORD_STORE_DIR"
if [[ -n "$PASS_PREFIX" ]]; then
    search_dir="$PASSWORD_STORE_DIR/$PASS_PREFIX"
fi

entries=()
if [[ -f "${search_dir}.gpg" ]]; then
    entries+=("$PASS_PREFIX")
elif [[ -d "$search_dir" ]]; then
    while IFS= read -r -d '' file; do
        entry="${file#"$PASSWORD_STORE_DIR/"}"
        entry="${entry%.gpg}"
        entries+=("$entry")
    done < <(find -L "$search_dir" -type f -name '*.gpg' -print0)
else
    echo "错误：找不到 pass 条目或目录：${PASS_PREFIX:-/}" >&2
    exit 2
fi

if ((${#entries[@]} == 0)); then
    echo "未找到可检查的密码条目。"
    exit 0
fi

declare -A password_entries=()
declare -A password_counts=()
read_failures=0

for entry in "${entries[@]}"; do
    # pass 条目的第一行是密码；不会输出或记录密码明文。
    if ! password="$(pass show "$entry" 2>/dev/null | sed -n '1p')"; then
        echo "警告：无法读取条目：$entry" >&2
        ((read_failures += 1))
        continue
    fi

    if [[ -z "$password" ]]; then
        echo "警告：条目的第一行为空：$entry" >&2
        continue
    fi

    # 使用 SHA-256 作为内存中的分组键，避免在��告警中暴露密码。
    password_hash="$(printf '%s' "$password" | sha256sum | awk '{print $1}')"
    password_counts["$password_hash"]=$(( ${password_counts["$password_hash"]:-0} + 1 ))

    if [[ -n "${password_entries["$password_hash"]:-}" ]]; then
        password_entries["$password_hash"]+=$'\n'"$entry"
    else
        password_entries["$password_hash"]="$entry"
    fi

done

duplicate_groups=0
duplicate_entries=0

for password_hash in "${!password_counts[@]}"; do
    count="${password_counts[$password_hash]}"
    if ((count > 1)); then
        ((duplicate_groups += 1))
        ((duplicate_entries += count))
        echo "告警：发现 $count 个条目使用相同密码："
        while IFS= read -r entry; do
            printf '  - %s\n' "$entry"
        done <<< "${password_entries[$password_hash]}"
        echo
    fi
done

if ((duplicate_groups > 0)); then
    echo "检查结果：发现 $duplicate_groups 组重复密码，涉及 $duplicate_entries 个条目。" >&2
    exit 1
fi

echo "检查结果：未发现重复密码；已检查 ${#entries[@]} 个条目。"
if ((read_failures > 0)); then
    echo "注意：有 $read_failures 个条目读取失败。" >&2
    exit 2
fi
