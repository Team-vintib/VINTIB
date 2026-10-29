# BE — 백엔드 코드 규칙

루트 `CLAUDE.md`의 공통 규칙이 먼저다. 이 문서는 `BE/` 코드를 바꿀 때의 규칙만 적는다. 실행 방법·패키지 지도는 `README.md`.

## 완료의 기준

- **`/verify`가 통과해야 완료다**(Gradle 전체 빌드 + 테스트). 중간에는 `./gradlew compileJava compileTestJava`나 `./gradlew test --tests '...'`로 좁혀 돌려도 되지만, 커밋 전에는 전체를 돌린다.
- **테스트 수가 줄면 안 된다.** 테스트를 지우거나 합쳤다면 커밋 메시지에 이유를 적는다.
- 테스트는 로컬 PostgreSQL·Redis·MinIO가 필요하다(`@SpringBootTest`, `S3BucketInitializer`). 루트에서 `docker compose up -d postgres redis minio`. Testcontainers로 바꾸면 이 줄을 갱신한다.

## 테스트

- 테스트 메서드명은 한글로 검증 의도를 쓴다. 예: `방송이_끝나면_진행_중인_경매를_잠금_후_마감한다()`.
- **결함 수정은 실패하는 테스트를 먼저 쓴다.** 수정 전에 그 테스트가 실패하는 것을 한 번 확인한다.
- **동시성·트랜잭션 결함은 Mockito 단위 테스트로 잡히지 않는다.** 행 잠금, 롤백 시 상태 유실, 커밋 후 브로드캐스트 같은 것은 실제 DB를 쓰는 `@SpringBootTest`/`@DataJpaTest`로 검증한다. 동시 입찰은 `AuctionBidStompTest`의 `CountDownLatch` 방식을 따른다.

## 트랜잭션과 스레드

- **트랜잭션 안에서 외부 I/O를 하지 않는다.** AI 게이트웨이, 토스, 배송 조회, 구글 OAuth, LiveKit 모두 해당한다. 순서는 "저장 → 커밋 → 외부 호출 → 결과를 별도 트랜잭션으로 반영"이다.
- **Redis만 쓰는 로직에 `@Transactional`을 붙이지 않는다.** DB 커넥션을 쓸데없이 잡는다.
- **같은 클래스 안의 메서드 호출에는 `@Transactional`이 걸리지 않는다**(self-invocation). 건별 트랜잭션이 필요하면 `AuctionCloseScheduler` → `AuctionCloseService.closeIfDue`처럼 루프와 처리를 다른 빈에 둔다.
- **바깥에 알리는 일은 커밋 후에 한다.** 컨트롤러에서 서비스 반환 뒤에 보내거나 `@TransactionalEventListener(AFTER_COMMIT)`을 쓴다.
- **실시간 경로(입찰·경매 마감·STOMP 처리)에서 블로킹 I/O를 하지 않는다.** 보조 기능(알림·외부 API 호출·AI 배치)은 전용 executor와 짧은 타임아웃, 실패 시 통과(fallback)로 격리한다.
- **새 executor·스케줄러·커넥션 풀은 크기와 큐 길이를 명시하고 메트릭을 노출한다.** 기본값에 기대지 않는다. 크기는 측정 근거로 정하고, 근거를 주석에 남긴다.
- **벌크 UPDATE의 `clearAutomatically`는 영속성 컨텍스트를 비운다.** `ProductCommandPort.markSold`처럼 쓰는 곳에서는 호출 순서가 의미를 가진다. 마지막에 호출한다.

## 경매·포인트 불변식

- 입찰은 `AuctionRepository.findByIdForUpdate`(PESSIMISTIC_WRITE)로 직렬화한다. 부분 UNIQUE 인덱스 `ux_bid_auction_price`·`ux_point_hold_member_active`·`ux_auction_live_running`는 최후 방어선이다. Redis 분산락·MQ로 바꾸지 않는다.
- 경매를 마감하는 모든 경로는 행 잠금 후 상태를 다시 확인한다.
- 같은 회원의 보류를 해제한 뒤 다시 만드는 순서를 만들지 않는다. 부분 UNIQUE 제약이 그 사이에 무력화된다(`PointHold` 주석).
- 포인트는 버킷(`available/bidHeld/tradeEscrow/settling/withdrawing`)과 원장(`point_transaction`)을 함께 움직인다. 버킷만 바꾸는 경로를 만들지 않는다.

## 스키마

- **지금은 `ddl-auto=update`다(Flyway 도입 전).** 엔티티를 바꾸면 운영 DB가 그대로 바뀐다. 행이 있는 테이블에 NOT NULL 컬럼을 추가하면 Hibernate가 실패를 로그로만 남기고 컬럼 없이 기동한다. 기본값을 주거나 `infra/ec2/restore-dump.sql`처럼 직접 ALTER를 준비한다.
- **`BE/docs/db/schema.sql`은 운영 DB와 다르다.** 스키마 판단은 운영 DB(`information_schema`)를 기준으로 한다.
- Flyway 도입 후에는 스키마 변경을 마이그레이션 파일로만 하고, `schema.sql`은 그 결과로 다시 생성한다.

## 코드 컨벤션 (팀 시절 규칙 유지)

- 패키지: `com.ssafy.backend.<domain>.{controller,service,entity,repository,dto/{request,response}}`. 엔티티 패키지명은 `entity`. 다른 도메인 참조는 `port` 인터페이스로 격리한다(`auction/port/*`). 새 도메인의 뼈대는 `.claude/skills/scaffold`(이 폴더 범위 스킬)로 만든다.
- 엔티티에 `@Setter`를 두지 않는다. 상태 전이는 엔티티의 의도 있는 메서드가 소유한다(`Auction.start/applyBid/closeAsSuccess`).
- 요청 DTO는 record + Bean Validation(`@Valid`).
- 응답은 `ApiResponse<T>` 한 겹. 예외는 `CustomException(ErrorCode)`. `ErrorCode`는 도메인 접두어 구역(A 경매, L 라이브, U 회원, W 포인트, O 주문, P 상품, T 시착, C 공통 등)을 지켜 추가한다. **기존 코드 값은 바꾸지 않는다**(FE가 분기한다).
- 엔드포인트를 바꾸면 Swagger 어노테이션(`@Tag`/`@Operation`/`@ApiResponses`/`@Schema`)을 함께 고친다. 설명은 실제 동작과 같아야 한다. 규칙은 `.claude/skills/swagger`.
- 주석에는 "무엇"이 아니라 "왜"를 쓴다. 기존 코드의 설계 근거 주석(JY0xx 참조 등)은 동작을 바꿀 때 함께 고친다.
