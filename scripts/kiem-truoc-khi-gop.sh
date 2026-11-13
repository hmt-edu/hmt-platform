#!/usr/bin/env bash
# Cổng kiểm trước khi gộp PR (việc G, Chat 11/11). Dùng:  scripts/kiem-truoc-khi-gop.sh <số PR>
# In từng mục PASS hoặc FAIL kèm lý do, cuối cùng một dòng "KẾT QUẢ: PASS" hoặc "KẾT QUẢ: FAIL". Thoát 0 khi PASS, 1 khi FAIL.
# Chỉ dùng gh api (REST), không cần token trong file (gh đã đăng nhập sẵn trên máy). Kiểm:
#  (1) mã commit cuối của PR;  (2) CI xanh trên ĐÚNG commit đó (check-runs, không tính job bị bỏ qua);
#  (3) có bình luận OK hợp lệ đăng SAU commit cuối: «OK» của caotruong276, hoặc «OK-CHAT-ĐÊM <mã commit>» khớp commit cuối;
#  (4) số migration của PR lớn hơn mọi số trên main, và không PR nào đang mở có số migration nhỏ hơn (phải gộp trước);
#  (5) nhánh không dirty (mergeable_state = clean).
# Không gộp giúp: chỉ kiểm. Dùng trước MỖI lần gộp.
set -uo pipefail

REPO="${HMT_REPO:-hmt-edu/hmt-platform}"
OWNER_OK="${HMT_OK_USER:-caotruong276}"
PR="${1:-}"
if ! [[ "$PR" =~ ^[0-9]+$ ]]; then
  echo "Cách dùng: $0 <số PR>" >&2
  exit 2
fi
command -v gh >/dev/null || { echo "Thiếu lệnh gh" >&2; exit 2; }
command -v python3 >/dev/null || { echo "Thiếu python3" >&2; exit 2; }

FAIL=0
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; FAIL=1; }
api() { gh api "$@"; }

pr_json="$(api "repos/$REPO/pulls/$PR")" || { echo "FAIL  Không đọc được PR #$PR"; echo "KẾT QUẢ: FAIL"; exit 1; }
py() { python3 -c "$1"; }
field() { printf '%s' "$pr_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }

state="$(field 'd["state"]')"
base="$(field 'd["base"]["ref"]')"
head_sha="$(field 'd["head"]["sha"]')"
title="$(field 'd["title"]')"
echo "PR #$PR: $title"
echo "Trạng thái: $state, nhánh gốc: $base"
if [ "$state" != "open" ]; then fail "PR không còn mở ($state)"; fi
if [ "$base" != "main" ]; then fail "PR không nhắm vào main (nhắm $base)"; fi

# (1) Mã commit cuối và giờ commit cuối.
commit_date="$(api "repos/$REPO/commits/$head_sha" --jq '.commit.committer.date')"
echo "(1) Commit cuối: $head_sha (lúc $commit_date)"
pass "(1) Đã đọc commit cuối của PR"

# (2) CI xanh trên đúng commit đó.
checks_json="$(api "repos/$REPO/commits/$head_sha/check-runs" --paginate --jq '.check_runs[] | {name, status, conclusion}' | python3 -c '
import json,sys
rows=[json.loads(l) for l in sys.stdin if l.strip()]
print(json.dumps(rows))')"
files_json="$(api "repos/$REPO/pulls/$PR/files" --paginate --jq '.[].filename' | python3 -c '
import json,sys
print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')"
ci_result="$(CHECKS="$checks_json" FILES="$files_json" python3 - <<'PY'
import json,os
rows=json.loads(os.environ["CHECKS"]); files=json.loads(os.environ["FILES"])
real=[r for r in rows if r["conclusion"]!="skipped"]
bad=[r for r in real if r["status"]!="completed" or r["conclusion"] not in ("success","neutral")]
docs_only=bool(files) and all(f.startswith(("docs/","design/")) or f.endswith(".md") for f in files)
if bad:
    print("FAIL|CI chưa xanh: " + ", ".join(f'{r["name"]} ({r["conclusion"] or r["status"]})' for r in bad))
elif not any(r["conclusion"]=="success" for r in real):
    print("PASS|không có job CI nào chạy (PR chỉ tài liệu/thiết kế, theo CLAUDE.md không chạy CI)" if docs_only else "FAIL|không có job CI nào chạy xong trên commit này")
else:
    print("PASS|CI xanh: " + ", ".join(r["name"] for r in real if r["conclusion"]=="success"))
PY
)"
if [ "${ci_result%%|*}" = "PASS" ]; then pass "(2) ${ci_result#*|}"; else fail "(2) ${ci_result#*|}"; fi

# (3) Bình luận OK hợp lệ đăng sau commit cuối.
comments_json="$(api "repos/$REPO/issues/$PR/comments" --paginate --jq '.[] | {user: .user.login, created_at, body, html_url}' | python3 -c '
import json,sys
print(json.dumps([json.loads(l) for l in sys.stdin if l.strip()]))')"
ok_result="$(COMMENTS="$comments_json" HEAD="$head_sha" AFTER="$commit_date" OWNER="$OWNER_OK" python3 - <<'PY'
import json,os,re
cs=json.loads(os.environ["COMMENTS"]); head=os.environ["HEAD"]; after=os.environ["AFTER"]; owner=os.environ["OWNER"]
found=None
for c in cs:
    if c["created_at"]<=after: continue
    body=c["body"].strip()
    if c["user"]==owner and re.match(r"^OK\b", body, re.I|re.U):
        found=("OK của "+owner, c)
    m=re.search(r"OK-CHAT-ĐÊM\s+([0-9a-f]{7,40})", body, re.I)
    if m and head.lower().startswith(m.group(1).lower()):
        found=("OK-CHAT-ĐÊM "+m.group(1), c)
if found: print("PASS|"+found[0]+" lúc "+found[1]["created_at"]+" "+found[1]["html_url"])
else: print("FAIL|chưa có OK hợp lệ đăng sau commit cuối (OK của "+owner+" hoặc OK-CHAT-ĐÊM <mã commit>); OK cũ trước commit cuối không tính")
PY
)"
if [ "${ok_result%%|*}" = "PASS" ]; then pass "(3) ${ok_result#*|}"; else fail "(3) ${ok_result#*|}"; fi

# (4) Số migration: lớn hơn mọi số trên main; không PR mở nào có số nhỏ hơn.
#     PR dựng chồng trên PR khác (nhánh nối tiếp) chứa luôn file migration của PR dưới: mỗi file migration tính cho PR mở có SỐ PR NHỎ NHẤT chứa nó.
mig_result="$(
  main_nums="$(api "repos/$REPO/contents/supabase/migrations?ref=main" --jq '.[].name' | python3 -c '
import re,sys
print(" ".join(m.group(1) for l in sys.stdin for m in [re.match(r"^\d{8}(\d{6})_",l)] if m))')"
  rows=""
  for n in $(api "repos/$REPO/pulls?state=open&per_page=100" --jq '.[].number'); do
    for f in $(api "repos/$REPO/pulls/$n/files" --paginate --jq '.[].filename' | grep '^supabase/migrations/' || true); do
      rows="$rows $n|$f"
    done
  done
  PR="$PR" MAIN="$main_nums" ROWS="$rows" python3 - <<'PY'
import os,re
pr=int(os.environ["PR"]); main=[int(x) for x in os.environ["MAIN"].split()]
owner={}
for item in os.environ["ROWS"].split():
    n,f=item.split("|",1); n=int(n)
    m=re.match(r"^supabase/migrations/\d{8}(\d{6})_",f)
    if not m: continue
    num=int(m.group(1))
    key=(f,num)
    owner[key]=min(owner.get(key,n),n)
mine=sorted(num for (f,num),o in owner.items() if o==pr)
if not mine:
    print("PASS|PR không có migration riêng"); raise SystemExit
mx=max(main) if main else 0
if min(mine)<=mx:
    print(f"FAIL|số migration {min(mine)} không lớn hơn số cao nhất trên main ({mx})"); raise SystemExit
# Bỏ số đã có trên main: nhánh của PR khác chưa gộp main nên diff vẫn liệt kê file đã gộp.
lower=sorted({f"#{o} (số {num})" for (f,num),o in owner.items() if o!=pr and mx<num<min(mine)})
if lower:
    print("FAIL|còn PR mở có số migration nhỏ hơn, phải gộp trước: "+", ".join(lower)); raise SystemExit
print(f"PASS|migration {', '.join(map(str,mine))} lớn hơn main ({mx}) và không PR mở nào có số nhỏ hơn")
PY
)"
if [ "${mig_result%%|*}" = "PASS" ]; then pass "(4) ${mig_result#*|}"; else fail "(4) ${mig_result#*|}"; fi

# (5) Nhánh không dirty. GitHub tính chậm sau khi main đổi: thử lại vài lần khi còn "unknown".
ms=""
for _ in 1 2 3 4 5; do
  ms="$(api "repos/$REPO/pulls/$PR" --jq '.mergeable_state')"
  [ "$ms" != "unknown" ] && break
  sleep 3
done
if [ "$ms" = "clean" ]; then pass "(5) Nhánh sạch (mergeable_state = clean)"; else fail "(5) mergeable_state = $ms (cần clean; dirty là xung đột với main)"; fi

echo
if [ "$FAIL" -eq 0 ]; then echo "KẾT QUẢ: PASS"; exit 0; else echo "KẾT QUẢ: FAIL"; exit 1; fi
