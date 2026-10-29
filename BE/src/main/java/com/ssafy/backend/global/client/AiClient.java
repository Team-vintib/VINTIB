package com.ssafy.backend.global.client;

import com.ssafy.backend.global.client.dto.AiJobCreatedResponse;
import com.ssafy.backend.global.client.dto.AiJobResponse;
import com.ssafy.backend.global.client.dto.PricingEstimateJobRequest;
import com.ssafy.backend.global.client.dto.ProductClassifyJobRequest;
import com.ssafy.backend.global.client.dto.QualityInspectionJobRequest;
import com.ssafy.backend.global.client.dto.RegistrationModelCutJobRequest;
import com.ssafy.backend.global.client.dto.SimilarProductAiResponse;
import com.ssafy.backend.global.client.dto.TryOnJobRequest;
import java.util.List;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

/**
 * FastAPI AI 게이트웨이 호출 클라이언트. job 생성·폴링 엔드포인트는 워커 전용이 아니라
 * BE가 호출하는 쪽이라 인증 헤더가 필요 없다(`AI/docs/infra-architecture.md`)
 */
@Slf4j
@Component
public class AiClient {

    private final RestClient aiRestClient;

    public AiClient(RestClient aiRestClient) {
        this.aiRestClient = aiRestClient;
    }

    /**
     * FastAPI 게이트웨이 도달 여부만 확인한다. AI 서버가 죽어도 백엔드는 계속 떠 있어야 하므로
     * 예외를 삼키고 false 를 돌려준다.
     */
    public boolean isHealthy() {
        try {
            aiRestClient.get()
                    .uri("/health")
                    .retrieve()
                    .toBodilessEntity();
            return true;
        } catch (RestClientException e) {
            log.warn("AI 서버 헬스체크 실패: {}", e.getMessage());
            return false;
        }
    }

    /** {@code POST /ai/tryon} — 핵심 AI 시착 job 생성. */
    public String createTryOnJob(TryOnJobRequest request) {
        AiJobCreatedResponse response = aiRestClient.post()
                .uri("/ai/tryon")
                .body(request)
                .retrieve()
                .body(AiJobCreatedResponse.class);
        return response.jobId();
    }

    /** {@code POST /ai/tryon/registration-model-cut} — 등록 시 AI 착용컷 job 생성. */
    public String createRegistrationModelCutJob(String productImageUrl, String gender, String maskType) {
        AiJobCreatedResponse response = aiRestClient.post()
                .uri("/ai/tryon/registration-model-cut")
                .body(new RegistrationModelCutJobRequest(productImageUrl, gender, maskType))
                .retrieve()
                .body(AiJobCreatedResponse.class);
        return response.jobId();
    }

    /**
     * {@code POST /quality/inspections} — 앞/뒤 사진이 갖춰지면 하자 검수 job 생성.
     *
     * <p>{@code include_descriptions}/{@code include_attention_maps}는 켠다 — 워커 연동
     * 검증 단계라 VLM 설명과 판단 근거(attention map) 둘 다 실제로 받아 확인해야 한다.
     * {@code include_annotated_images}는 끈다 — FE가 bbox를 좌표로 직접 그리기로 해서 정적
     * PNG가 필요 없어졌다(2026-08-08). 다 지연시간이 늘어나는 옵션이라, 필요 없어지면 다시
     * 검토할 여지가 있다.
     */
    public String createQualityInspectionJob(Long productId, List<String> imageUrls, String category) {
        AiJobCreatedResponse response = aiRestClient.post()
                .uri("/quality/inspections")
                .body(new QualityInspectionJobRequest(productId, imageUrls, category, true, true, false))
                .retrieve()
                .body(AiJobCreatedResponse.class);
        return response.jobId();
    }

    /**
     * {@code POST /product-classifier/classify} — 상품 생성 전 사진 1장으로 카테고리·색상 분류
     * job 생성(`docs/requests/BE/045-classify-pre-upload-integration.md`). 아직 상품이 없는
     * 시점에 호출하므로 {@code product_id}는 보내지 않는다.
     */
    public String createClassifyJob(String imageUrl) {
        AiJobCreatedResponse response = aiRestClient.post()
                .uri("/product-classifier/classify")
                .body(new ProductClassifyJobRequest(imageUrl))
                .retrieve()
                .body(AiJobCreatedResponse.class);
        return response.jobId();
    }

    /**
     * {@code POST /pricing/estimates} — 상품 등록 화면 "AI 가격 추천" 트리거. 동시 처리
     * 상한을 넘으면 AI가 503을 낸다 — 그대로 {@link RestClientException}으로 던져서 호출부가
     * 처리하게 한다(재시도는 하지 않는다, FE가 등급별로 나눠 호출하는 쪽에서 책임진다).
     */
    public String createPricingEstimateJob(PricingEstimateJobRequest request) {
        AiJobCreatedResponse response = aiRestClient.post()
                .uri("/pricing/estimates")
                .body(request)
                .retrieve()
                .body(AiJobCreatedResponse.class);
        return response.jobId();
    }

    /** {@code GET /ai/jobs/{jobId}} — 모든 AI 기능이 공유하는 공통 job 상태 조회. */
    public AiJobResponse getJob(String jobId) {
        return aiRestClient.get()
                .uri("/ai/jobs/{jobId}", jobId)
                .retrieve()
                .body(AiJobResponse.class);
    }

    /**
     * {@code GET /recommend/products/{productId}/similar} — CLIP 임베딩 기반 유사 상품 후보
     * 조회(CH034). {@code SimilarProductCacheService}(배치)에서만 호출한다 — 상품 상세
     * 서빙 경로(`ProductQueryService`/`SimilarProductQueryService`)는 이 메서드를 부르지 않는다,
     * AI 서버 상태가 상품 상세 응답에 영향을 주면 안 되기 때문이다.
     */
    public SimilarProductAiResponse getSimilarProducts(Long productId, int k) {
        return aiRestClient.get()
                .uri("/recommend/products/{productId}/similar?k={k}", productId, k)
                .retrieve()
                .body(SimilarProductAiResponse.class);
    }
}
