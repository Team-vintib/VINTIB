---
name: request
description: Write, answer, or update a cross-part request document under docs/requests/ (BE·infra·FE·AI·owner). Use when work needs a change or decision outside this repo's scope (FE/AI feature code, API contract change, owner decision), when the user says "요청 남겨", "답변 달아", or when a session starts and docs/requests/README.md has open requests addressed to the current part.
---

# 요청·응답 문서

규칙의 원문은 `docs/requests/README.md`. 이 스킬은 그 규칙대로 쓰는 순서다.

## 요청 쓰기

1. 정말 요청이 필요한지 본다. 자기 파트 범위 안이면 요청 없이 그냥 한다.
2. 파일을 만든다: `docs/requests/YYYY-MM-DD-<요청쪽>-<받는쪽>-<slug>.md`, 내용은 `_template.md`를 복사해서.
   - 파트 코드: `be` `infra` `fe` `ai` `owner`. slug는 영문 소문자 kebab-case.
   - 배경에는 근거 경로(필요하면 커밋 해시)를 적는다. 추측이면 추측이라고 쓴다.
   - 요청 내용은 받는 쪽이 하나씩 답할 수 있게 체크 항목으로. 선택지가 있으면 추천을 먼저.
3. `docs/requests/README.md` 색인 표 맨 위에 행을 더한다(최신이 위).
4. 사용자에게 요청 내용을 보여 주고 승인받은 뒤 커밋한다: `docs(requests): <제목> [<관련 항목>]`.
5. 요청이 풀릴 때까지 막히는 일이면, 그 사실을 계획 문서의 해당 항목과 보고에 적는다.

## 응답하기

1. 문서의 "응답" 절을 채운다: 응답자·날짜, 결정(수락 | 수정 수락 | 보류 | 거절), 항목별 답.
2. 머리의 `- 상태:`를 `답변`(보류·거절이면 그 값)으로 바꾸고, 색인 표의 상태도 **같은 커밋에서** 바꾼다.
3. 요청과 다르게 정했으면 이유를 쓴다. 결정이 사용자 몫이면 `owner`의 답을 받기 전에 확정하지 않는다.

## 반영하기

1. 결정대로 바꾸는 커밋(또는 PR)을 만든다.
2. "반영" 절에 커밋·PR과 확인 방법(테스트·측정·화면)을 적고, 상태를 `반영`으로 바꾼다. 색인 표도 같이.

## 세션 시작·pull 직후

- `docs/requests/README.md` 색인에서 상태가 `요청`이고 받는 쪽이 지금 작업하는 파트(또는 `owner`)인 문서를 찾아 사용자에게 한 줄씩 알린다.
- 팀 시절 문서(`docs/requests/<파트>/…`)는 기록용이다. 처리하지 않는다.

## 하지 않는 것

- 처리한 요청 문서를 지우지 않는다(팀 시절 규칙과 다르다).
- 요청을 이유로 범위 밖 코드를 직접 고치지 않는다. 받는 쪽의 결정과 반영이 먼저다.
