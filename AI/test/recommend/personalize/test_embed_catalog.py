"""embed_catalog(오프라인 임베딩 파이프라인) 테스트.

순수 로직(텍스트 조합)은 가드 없이 그대로 실행한다. 실제 모델을 로드하는 임베딩 경로는
`kanana-nano-2.1b-embedding`의 커스텀 모델 코드(`trust_remote_code`)가 지금 핀된
transformers 버전과 호환되지 않아(`AttributeError: 'tuple' object has no attribute
'dtype'`, modeling_kanana2vec.py 내부) 명시적으로 skip한다.
"""

import pytest

from app.recommend.pipeline.embed_catalog import _product_text


def test_product_text_joins_title_and_brand():
    row = {"title": "빈티지 리바이스 데님 자켓", "brand": "Levi's"}
    assert _product_text(row) == "빈티지 리바이스 데님 자켓 Levi's"


def test_product_text_skips_missing_brand():
    row = {"title": "빈티지 플로럴 원피스", "brand": None}
    assert _product_text(row) == "빈티지 플로럴 원피스"


@pytest.mark.skip(
    reason=(
        "kanana-nano-2.1b-embedding 커스텀 모델 코드가 transformers==4.51.3과 호환되지 "
        "않는다(AttributeError: 'tuple' object has no attribute 'dtype', "
        "modeling_kanana2vec.py) — 추천 임베딩 파이프라인 담당이 별도로 조사 필요"
        "(버전 호환 확인 또는 revision 고정)."
    )
)
def test_embed_texts_importorskip_guard():
    from app.recommend.pipeline.embed_catalog import embed_texts

    vectors = embed_texts(["빈티지 데님 자켓", "플로럴 원피스"])
    assert vectors.shape[0] == 2
