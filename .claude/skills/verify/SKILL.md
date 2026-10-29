---
name: verify
description: Run the backend verification (full Gradle build with all tests) before calling any BE change done. Use after editing BE/ code, before committing, or when the user asks to verify or run the tests.
---

# BE 검증

`BE/`를 바꿨다면 커밋 전에 이 순서로 실행하고, 전부 통과해야 완료로 본다. CI 워크플로가 생기면 그 테스트 잡과 이 절차를 같은 명령으로 맞춘다.

## 1. 의존 서비스

테스트가 로컬 PostgreSQL·Redis·MinIO에 붙는다(`@SpringBootTest`, `S3BucketInitializer`). Docker Desktop이 켜져 있어야 한다. 레포 루트에서:

```bash
[ -f .env ] || cp .env.example .env
docker compose up -d postgres redis minio
```

`docker-compose.override.yml`이 로컬 포트(5432·6379·9000)를 연다. Testcontainers로 바꾸면 이 절을 지운다.

## 2. 빌드 + 테스트

```bash
cd BE
./gradlew build --no-daemon
```

- 반복 중에는 `./gradlew compileJava compileTestJava` 또는 `./gradlew test --tests '<클래스명>'`으로 좁힌다.
- 완료 판단은 반드시 위 전체 빌드로 한다.

## 3. 테스트 수 확인

```bash
grep -r "@Test" BE/src/test --include=*.java | wc -l
```

줄었다면 이유를 커밋 메시지에 적는다.

## 4. 실패하면

- 컴파일 실패: 에러의 파일·라인을 고치고 `compileJava compileTestJava`로 다시 확인한다.
- 테스트 실패: `BE/build/reports/tests/test/index.html` 또는 `BE/build/test-results/test/*.xml`에서 원인을 본다. DB 접속 실패는 Hibernate가 "Unable to determine Dialect"로 덮어쓰므로 1절의 컨테이너 상태부터 확인한다.
- 통과할 때까지 반복한다. 실패한 채로 완료를 보고하지 않는다.

## 완료 기준

`BUILD SUCCESSFUL`과 테스트 수 유지. 보고에 실행한 테스트 수를 적는다.
