#!/bin/bash
# 9 個 app 的 Cargo.lock 同步 MR(每個 repo):
#  1. 開 issue "Update Cargo.lock for Rust Application Packages" → iid
#  2. 從(fetch 後的)origin/NOS_v6.0_develop 開分支 <iid>-update-cargo.lock-for-rust-app,
#     cherry-pick clippy-scan-binary-packages-3 上的 "Synchonize Cargo.lock" commit,
#     message 改為 "Issue #<iid>: Update Cargo.lock for Rust Application Packages"
#  3. push + 開 MR(target=NOS_v6.0_develop,Closes #<iid>)。【不 merge】
# 預設 DRY-RUN;確認後加 --go。
set -u
DL=/home/moxa/sda2/home/moxa/NOS_v6.0_develop/buildroot/dl
SRC_BR=clippy-scan-binary-packages-3
TARGET=NOS_v6.0_develop
TITLE="Update Cargo.lock for Rust Application Packages"
TOKEN_FILE=${TOKEN_FILE:-$HOME/moxa_gitlab_scm_token}
LIST_FILE=${LIST_FILE:-/tmp/cargolock_apps.txt}
GO=0; [ "${1:-}" = "--go" ] && GO=1
TOKEN=$(grep -oE 'glpat-[A-Za-z0-9._-]+' "$TOKEN_FILE" | head -1)
api(){ curl -sS --max-time 30 --header "PRIVATE-TOKEN: $TOKEN" "$@" </dev/null; }
cd "$DL" || exit 1
done_n=0; skip_n=0; fail=""
while read -r r; do
  [ -d "$r/.git" ] || continue
  enc=$(git -C "$r" remote get-url origin | sed -E 's#^.*gitlab\.com[:/]##; s#\.git$##; s#/#%2F#g')
  commit=$(git -C "$r" log --no-ext-diff --format='%H %s' "$SRC_BR" 2>/dev/null | grep -m1 'Synchonize Cargo.lock' | awk '{print $1}')
  [ -n "$commit" ] || { echo "SKIP(無 lock commit) $r"; skip_n=$((skip_n+1)); continue; }
  if git -C "$r" ls-remote origin 'refs/heads/*-update-cargo.lock-for-rust-app' 2>/dev/null | grep -q .; then
    echo "EXISTS $r"; skip_n=$((skip_n+1)); continue; fi
  iid=$(api "https://gitlab.com/api/v4/projects/$enc/issues?state=opened&search=$(printf %s "$TITLE" | sed 's/ /%20/g')" \
        | jq -r --arg t "$TITLE" '[.[]|select(.title==$t)][0].iid // empty')
  if [ -z "$iid" ]; then
    if [ "$GO" = 1 ]; then
      iid=$(api --request POST "https://gitlab.com/api/v4/projects/$enc/issues" --data-urlencode "title=$TITLE" | jq -r '.iid // empty')
      [ -n "$iid" ] || { echo "FAIL(開issue) $r"; fail="$fail $r"; continue; }
    else iid="<NEW>"; fi
  fi
  newbr="${iid}-update-cargo.lock-for-rust-app"; msg="Issue #${iid}: ${TITLE}"
  if [ "$GO" = 0 ]; then echo "DRY  $r  issue=#$iid  branch=$newbr  cherry-pick=${commit:0:10}  → MR to $TARGET"; continue; fi
  [ -z "$(git -C "$r" status --porcelain)" ] || { echo "FAIL(工作樹不乾淨) $r"; fail="$fail $r"; continue; }
  git -C "$r" fetch -q origin "$TARGET" || { echo "FAIL(fetch) $r"; fail="$fail $r"; continue; }
  git -C "$r" checkout -q -B "$newbr" FETCH_HEAD || { echo "FAIL(checkout base) $r"; fail="$fail $r"; continue; }
  if ! git -C "$r" cherry-pick "$commit" >/dev/null 2>&1; then
    git -C "$r" cherry-pick --abort 2>/dev/null; echo "FAIL(cherry-pick衝突) $r"; fail="$fail $r"; continue; fi
  git -C "$r" commit -q --amend -m "$msg"
  git -C "$r" push -q -u origin "$newbr" || { echo "FAIL(push) $r"; fail="$fail $r"; continue; }
  resp=$(api --request POST "https://gitlab.com/api/v4/projects/$enc/merge_requests" \
    --data-urlencode "source_branch=$newbr" --data-urlencode "target_branch=$TARGET" \
    --data-urlencode "title=$msg" --data-urlencode "description=Closes #${iid}" --data "remove_source_branch=true")
  mrurl=$(echo "$resp" | jq -r '.web_url // empty')
  [ -n "$mrurl" ] && { echo "OK   $r  issue #$iid  → $mrurl"; done_n=$((done_n+1)); } || { echo "FAIL(MR) $r : $(echo "$resp"|jq -rc '.message//.')"; fail="$fail $r"; }
  [ "${SLEEP:-0}" != 0 ] && sleep "${SLEEP}"
done < "$LIST_FILE"
echo "---------"; echo "完成=$done_n 跳過=$skip_n 失敗:${fail:- 無}"
[ "$GO" = 0 ] && echo "(DRY-RUN)"; exit 0
