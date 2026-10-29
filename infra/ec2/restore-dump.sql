-- 2026-08-10 익명화 운영 덤프(레포에 넣지 않는다. 원본은 팀 GitLab 레포의 SSAFY 제출 폴더)를 복원한 **직후**, backend 를 띄우기 **전에** 실행한다.
-- 여러 번 실행해도 결과가 같다.
--
-- 덤프(2026-08-10)를 이 레포의 엔티티와 같은 모양으로 맞춘다. ddl-auto=update 에 맡기면 안 되는 것들이다.
--   1) order_shipment.webhook_subscribed — NOT NULL 이라 행이 있는 테이블에 Hibernate 가 추가하지 못한다
--      (실패를 로그로만 남기고 컬럼 없이 기동한다 → 주문 조회가 런타임에 터진다).
--   2) product_defect → product.defects(JSONB) — 데이터 이관이 필요하다(SY047).
--   3) chat_message — 덤프에는 이 레포에 없는 is_blocked 컬럼과 'AI' 화자를 허용하는 체크 제약이 있다.
--      is_blocked 가 NOT NULL·기본값 없음이라 그대로 두면 채팅 저장이 실패한다. 차단 표시가 있던 메시지는
--      시청자 화면에 나간 적이 없으므로 지운다. Hibernate 는 기존 제약을 고치지 않으므로 직접 바꾼다.
--
--   docker exec -i vintib-postgres psql -U postgres -d vintib -v ON_ERROR_STOP=1 < infra/ec2/restore-dump.sql
BEGIN;

ALTER TABLE order_shipment
    ADD COLUMN IF NOT EXISTS webhook_subscribed BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE product ADD COLUMN IF NOT EXISTS defects JSONB;

DO $$
BEGIN
    IF to_regclass('public.product_defect') IS NOT NULL THEN
        UPDATE product p
           SET defects = d.items
          FROM (SELECT product_id, jsonb_agg(content ORDER BY sort_order, id) AS items
                  FROM product_defect
                 GROUP BY product_id) d
         WHERE d.product_id = p.id;
        DROP TABLE product_defect;
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_name = 'chat_message' AND column_name = 'is_blocked') THEN
        DELETE FROM chat_message WHERE is_blocked;
        ALTER TABLE chat_message DROP COLUMN is_blocked;
    END IF;
END $$;

DELETE FROM chat_message WHERE sender_type NOT IN ('USER', 'SYSTEM');
ALTER TABLE chat_message DROP CONSTRAINT IF EXISTS chat_message_sender_type_check;
ALTER TABLE chat_message DROP CONSTRAINT IF EXISTS ck_chat_sender_type;
ALTER TABLE chat_message ADD CONSTRAINT chat_message_sender_type_check
    CHECK (sender_type IN ('USER', 'SYSTEM'));
ALTER TABLE chat_message ADD CONSTRAINT ck_chat_sender_type
    CHECK (sender_type IN ('USER', 'SYSTEM'));

COMMIT;
