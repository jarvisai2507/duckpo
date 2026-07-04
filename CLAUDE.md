# duckpo — 일일 기록 게시판

이 저장소는 날짜별로 하루의 대화/일들을 기록하는 정적 게시판 웹사이트다.

- 웹페이지: https://jarvisai2507.github.io/duckpo/ (GitHub Pages, `main` 브랜치 push 시 자동 배포)
- 게시글 데이터: `logs/posts.json` (JSON 배열, `index.html`이 fetch해서 렌더링)
- 빌드 도구 없음 — 순수 정적 HTML/JS.

## ⭐ 대화 기록 규칙 (가장 중요)

사용자가 **"대화끝"**, **"오늘끝"**, 또는 이와 비슷한 말(예: "오늘 끝", "대화 끝", "기록해줘")을 하면, 반드시 다음을 수행한다:

1. **요약 작성**: 현재 세션에서 나눈 대화 전체를 한국어로 요약한다.
   - `title`: 대화의 핵심을 담은 짧은 제목 (한 줄)
   - `summary`: 요약문. 여러 문단/목록 가능. 대화 전문은 저장하지 않는다 — **요약만**.
2. **`logs/posts.json`에 새 항목 추가** (배열 맨 뒤에 append):
   ```json
   {
     "id": "YYYY-MM-DD-NNN",
     "date": "YYYY-MM-DD",
     "time": "HH:MM",
     "title": "제목",
     "summary": "요약문 (줄바꿈은 \\n)",
     "tags": ["태그"]
   }
   ```
   - 날짜/시간은 **한국 시간(KST, Asia/Seoul)** 기준: `TZ=Asia/Seoul date '+%Y-%m-%d %H:%M'`
   - `id`의 `NNN`은 같은 날짜 안에서 001부터 증가하는 일련번호 (예: 같은 날 두 번째 기록이면 `-002`)
   - `tags`는 대화 주제에 맞게 1~3개 (예: "개발", "일상", "업무")
3. **commit & push**: 커밋 메시지는 `기록: YYYY-MM-DD 제목` 형식.
4. **사용자에게 알림**: 기록이 게시되었다고 알리고 페이지 주소(https://jarvisai2507.github.io/duckpo/)를 함께 전한다.

주의:
- `posts.json`은 유효한 JSON이어야 한다. 추가 후 `python3 -m json.tool logs/posts.json`으로 검증할 것.
- 기존 항목을 수정하거나 삭제하지 말 것 (사용자가 명시적으로 요청한 경우 제외).
