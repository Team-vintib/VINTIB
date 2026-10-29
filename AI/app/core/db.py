"""AI 전용 벡터 저장소(postgres-vector) 접속.

BE 공유 DB(`config.db_*`)와는 별개 인스턴스다. 의류 임베딩(`app/recommend/personalize/
embedding_store.py`), 가격 책정 관측 로그·상품 코퍼스(`app/pricing/store.py`·
`product_corpus.py`), 품질검수 attention map 로그(`app/quality/attention_map_store.py`)가
`get_vector_engine()`으로 이 인스턴스를 쓴다.
"""

from __future__ import annotations

from collections.abc import Iterator
from functools import lru_cache

from sqlalchemy import Engine, create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import settings


def _vector_db_url() -> str:
    s = settings
    return (
        f"postgresql+psycopg://{s.vector_db_username}:{s.vector_db_password}"
        f"@{s.vector_db_host}:{s.vector_db_port}/{s.vector_db_name}"
    )


@lru_cache
def get_vector_engine() -> Engine:
    return create_engine(_vector_db_url(), pool_pre_ping=True)


@lru_cache
def _session_factory() -> sessionmaker[Session]:
    return sessionmaker(bind=get_vector_engine())


def get_vector_session() -> Iterator[Session]:
    """FastAPI 의존성 주입용. 직접 쓸 땐 `with Session(get_vector_engine()) as s:`도 가능."""
    session = _session_factory()()
    try:
        yield session
    finally:
        session.close()
