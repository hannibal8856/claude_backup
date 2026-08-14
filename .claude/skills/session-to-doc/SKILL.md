---
name: session-to-doc
description: >
  Turn a whole Claude Code session (reference material gathered, the
  discussion in the middle, and the final conclusions) into ONE structured
  Markdown document that doubles as (a) standalone explanatory documentation
  and (b) a slide-ready outline. Trigger on: "整理這次 session", "把這段對話
  整理成文件", "session to doc", "做成投影片大綱", "summarize this session
  into a doc", or after a /export transcript is provided.
---

# Session → Doc

## 輸入
- 優先讀使用者提供的 `/export` transcript 檔(完整保真:參考資料 + 討論 + 結論)。
- 若沒有 transcript,就直接綜整「當前這個 session」的內容。

## 輸出規則
- 產生一個 Markdown 檔(預設檔名 `session-<topic>-<date>.md`)。
- 每個 `##` 區段 = 之後一張投影片的份量;每段條列控制在 ~6 點內。
- 每段條列「下面」再補 2–4 句散文,讓文件單獨可讀。
- 程式碼/設定片段/指令一律放到最後的附錄,正文只放結論與理由。
- 全程用使用者的語言(預設繁體中文)。

## 文件結構(固定 schema)
1. `## TL;DR` — 一句話總結(之後當標題頁副標)。
2. `## 背景與目標` — 為什麼要做這件事、要解決什麼。
3. `## 參考資料 / 來源` — 這次討論引用到的資料清單(連結、檔案、指令出處),逐筆列出。
4. `## 討論脈絡` — 用「問題 → 候選方案 → 取捨 → 決定」記錄每個關鍵轉折,而非逐句流水帳。
5. `## 結論與決策` — 每條決策附「為什麼這樣選」。
6. `## 後續待辦 / 開放問題` — action items 與還沒收斂的問題。
7. `## 附錄` — 重要指令、設定片段、程式碼。

## 完成後
- 回報檔案路徑,並提醒:要做投影片時把這份檔交給 pptx skill,
  因為已是投影片優先結構,轉換會很乾淨。
