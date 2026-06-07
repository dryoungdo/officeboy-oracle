---
type: learning
topic: Claude Code ↔ NotebookLM Direct Connection — Deep Research
source: research
maturity: emerging
retrieval_terms: [notebooklm, claude-code, mcp, google-drive, automation, notebooklm-api, notebooklm-mcp, gemini-api]
date: 2026-06-07
gate_hook: verify-freshness-monthly
---

# Claude Code ↔ NotebookLM Direct Connection

## Executive Summary

Claude Code **สามารถเชื่อมต่อ NotebookLM ได้ 3 วิธี** — เรียงจากง่ายสุดไปยากสุด:

| วิธี | ความง่าย | ความเสถียร | ราคา |
|------|---------|------------|------|
| **MCP Server** (notebooklm-mcp) | ⭐⭐⭐ ง่ายสุด | 🟡 Medium (browser automation) | ฟรี |
| **Google Drive Bridge** + auto-sync | ⭐⭐ ปานกลาง | ✅ High (official feature) | ฟรี |
| **Enterprise API** | ⭐ ยาก | ✅ High (official) | 💰 ต้อง Gemini Enterprise license |

**ทางเลือกอื่น** ที่ไม่ต้องพึ่ง NotebookLM: Gemini Files API, Claude Projects, Custom GPT, AnythingLLM

---

## วิธี 1: MCP Server (แนะนำ — ง่ายสุดสำหรับ Claude Code)

### ตัวเลือกหลัก

| MCP Server | ภาษา | Stars | ล่าสุด | จุดเด่น |
|------------|-------|-------|--------|---------|
| **PleasePrompto/notebooklm-mcp** | Node.js | - | May 2026 | ออกแบบสำหรับ Claude Code โดยเฉพาะ |
| **jacob-bd/notebooklm-mcp-cli** | Python | - | Apr 2026 | 35 MCP tools + `nlm` CLI |
| **roomi-fields/notebooklm-mcp** | - | - | Apr 2026 | มี REST API ด้วย |

### ติดตั้ง (เร็วสุด)

```bash
# Option A — npm
npx notebooklm-mcp

# Option B — Python
pip install notebooklm-mcp-cli
```

เพิ่มใน `.claude/settings.json` > `mcpServers`

### ข้อจำกัด
- ใช้ browser automation (Patchright/Playwright) — ต้องมี Chrome/Chromium
- ต้อง login Google account ก่อน (cookies)
- เปราะต่อ UI changes ของ NotebookLM (เช่น April 2026 มี UI refresh ทำให้ต้อง update)

---

## วิธี 2: Google Drive Bridge + Auto-Sync

### Flow

```
Claude Code → Google Drive API (upload .md) → NotebookLM (auto-sync)
```

### ขั้นตอน
1. **Upload** ไฟล์ markdown ไปยัง Google Drive ผ่าน Drive API v3
2. **Link ครั้งเดียว** ใน NotebookLM UI: Add Source → Google Drive → เลือกไฟล์
3. **Auto-sync** (ฟีเจอร์ใหม่ May 26, 2026) — เมื่อไฟล์ใน Drive เปลี่ยน, NotebookLM refresh อัตโนมัติ

### ข้อดี
- ใช้ official Google feature — เสถียร
- ไม่ต้อง browser automation
- update ไฟล์ได้ตลอด ระบบ sync เอง

### ข้อจำกัด
- ต้อง link ไฟล์ใน UI ครั้งแรก (manual)
- Auto-sync ไม่ auto-discover ไฟล์ใหม่
- ต้องมี Google Drive API credentials (SA + domain-wide delegation หรือ OAuth)

---

## วิธี 3: Enterprise API (Official — องค์กรเท่านั้น)

### Endpoint
```
https://LOCATION-discoveryengine.googleapis.com/v1alpha/projects/PROJECT/locations/LOCATION/notebooks
```

### Operations
- `notebooks.create` / `notebooks.get` / `notebooks.delete`
- `notebooks.sources.batchCreate` — เพิ่ม source จาก Drive ID
- Audio overview generation
- Notebook queries

### Requirements
- Google Workspace Business/Enterprise plan หรือ Cloud billing
- Gemini Enterprise license
- `gcloud auth print-access-token` (user OAuth, ไม่รับ service account สำหรับ Drive sources)
- API version: `v1alpha` (ยังไม่ stable)

---

## วิธี 4: notebooklm-py (Reverse-Engineered API)

**github.com/teng-lin/notebooklm-py** — 5.6k+ stars, v0.6.0 (May 29, 2026)

```bash
pip install notebooklm-py
```

### ทำได้
- Notebook CRUD
- Source ingestion (URLs, YouTube, text, files)
- Chat/Q&A
- Audio overviews, slides, quizzes, flashcards, mind maps

### Auth
- ใช้ Google cookies (`__Secure-1PSID`, `__Secure-1PSIDTS`)
- ดึงจาก browser session

### MCP wrapper
- `notebooklm-py-mcp` — wrap เป็น MCP server ได้

### ข้อจำกัด
- Undocumented internal API — Google เปลี่ยนได้ตลอด
- ต้อง maintain cookies

---

## ทางเลือกอื่น (ไม่ใช้ NotebookLM)

### Tier 1 — แนะนำ

| ทางเลือก | ดียังไง | ราคา | Thai |
|----------|---------|------|------|
| **Gemini Files API** | Upload markdown → chat ได้เลย, context caching ถูก | Free tier มี | ✅ |
| **Claude Projects** | Upload docs → share link → ใช้ได้เลย | Pro $20/mo | ✅ |
| **Custom GPT** | Upload 20 files → share URL → คนทั่วไปใช้ได้ | Plus $20/mo | ✅ |

### Tier 2 — Self-hosted

| ทางเลือก | ดียังไง | ราคา |
|----------|---------|------|
| **AnythingLLM** | Docker, REST API, chat UI ครบ | ฟรี + LLM API cost |
| **Open Notebook** | Clone ของ NotebookLM, open-source | ฟรี + LLM API cost |
| **SurfSense** | Open-source NotebookLM alternative | ฟรี |

---

## คำแนะนำสำหรับ Captain

### ถ้าต้องการ NotebookLM จริงๆ
→ **ติดตั้ง `notebooklm-mcp`** เป็น MCP server ใน Claude Code
→ Claude จะสร้าง notebook, upload sources, query ได้ตรง
→ ต้อง login Google บน Chrome ก่อน

### ถ้าต้องการทางที่เสถียรสุด
→ **Google Drive Bridge**: upload ไฟล์ไป Drive → link ใน NotebookLM ครั้งเดียว → auto-sync

### ถ้าต้องการง่ายสุดสำหรับคนทั่วไปใช้
→ **Claude Projects** หรือ **Custom GPT**: upload ไฟล์ → share link

### ถ้าต้องการ full automation ไม่พึ่ง NotebookLM
→ **Gemini Files API**: upload folder → build chat wrapper → done

---

## Pre-publish Ledger

- Sources checked: WebSearch x5 agents, ~40+ URLs consulted
- Claims made: 12 (maturity: 🟡 Emerging — verified from multiple sources but no hands-on testing)
- Conflicts resolved: Enterprise API vs public API confusion — clarified: Enterprise only
- Application evidence: N/A — research only, no installation tested yet
- Codex reviewed: no

---

## Sources

### Official
- Google Cloud: NotebookLM Enterprise API — docs.cloud.google.com/gemini/enterprise/notebooklm-enterprise/docs/api-notebooks
- Google Workspace Updates: Drive auto-sync (May 2026)

### Community MCP Servers
- github.com/PleasePrompto/notebooklm-mcp
- github.com/jacob-bd/notebooklm-mcp-cli
- github.com/roomi-fields/notebooklm-mcp

### Libraries
- github.com/teng-lin/notebooklm-py (5.6k+ stars)
- github.com/gnh1201/notebooklm-rest-api
- github.com/K-dash/nblm-rs (Rust/Enterprise)

### Automation
- github.com/DataNath/notebooklm_source_automation (Playwright)
- github.com/adrianwedd/notebooklm-automation

### Registries
- mcpservers.org/servers/roomi-fields/notebooklm-mcp
- mcp.directory/servers/notebooklm
