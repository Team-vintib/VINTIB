package com.ssafy.backend.order.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.backend.global.exception.CustomException;
import com.ssafy.backend.global.exception.ErrorCode;
import com.ssafy.backend.member.entity.Member;
import com.ssafy.backend.member.repository.MemberRepository;
import com.ssafy.backend.order.dto.request.OrderCreateRequest;
import com.ssafy.backend.point.dto.response.PointBalanceResponse;
import com.ssafy.backend.point.service.PointService;
import com.ssafy.backend.product.entity.Category;
import com.ssafy.backend.product.entity.Product;
import com.ssafy.backend.product.entity.SaleStatus;
import com.ssafy.backend.product.repository.CategoryRepository;
import com.ssafy.backend.product.repository.ProductRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * 즉시구매 동시 요청 검증. 요청마다 트랜잭션이 따로 커밋돼야 하므로 테스트 트랜잭션으로 감싸지
 * 않고, 만든 데이터는 끝나고 직접 지운다.
 */
@SpringBootTest
class OrderConcurrencyIntegrationTest {

    @Autowired
    private OrderService orderService;

    @Autowired
    private PointService pointService;

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private CategoryRepository categoryRepository;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private final List<Long> memberIds = new ArrayList<>();
    private Member seller;
    private Long categoryId;

    @BeforeEach
    void setUp() {
        seller = 회원_생성("판매자");
        categoryId = categoryRepository.findAll().stream()
                .filter(category -> category.getParentId() != null)
                .map(Category::getId)
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("시드된 소분류 카테고리가 없다"));
    }

    @AfterEach
    void tearDown() {
        if (memberIds.isEmpty()) {
            return;
        }
        String ids = memberIds.stream().map(String::valueOf).reduce((a, b) -> a + "," + b).orElseThrow();
        jdbcTemplate.update("delete from notification where member_id in (" + ids + ")");
        jdbcTemplate.update("delete from point_transaction where member_id in (" + ids + ")");
        jdbcTemplate.update("delete from orders where buyer_id in (" + ids + ") or seller_id in (" + ids + ")");
        jdbcTemplate.update("delete from point_account where member_id in (" + ids + ")");
        jdbcTemplate.update("delete from product where seller_id in (" + ids + ")");
        jdbcTemplate.update("delete from member where id in (" + ids + ")");
    }

    @Test
    void 여러_명이_같은_상품을_동시에_사면_한_명만_성공한다() throws Exception {
        long price = 190_000L;
        Product product = 상품_등록(price);
        List<Member> buyers = new ArrayList<>();
        for (int i = 0; i < 6; i++) {
            Member buyer = 회원_생성("구매자" + i);
            pointService.charge(buyer.getId(), 500_000L, null);
            buyers.add(buyer);
        }

        List<Callable<Boolean>> tasks = buyers.stream()
                .<Callable<Boolean>>map(buyer -> () -> 구매(buyer.getId(), product.getId()))
                .toList();
        long succeeded = 동시에_실행(tasks);

        assertThat(succeeded).isEqualTo(1);
        assertThat(주문_수(product.getId())).isEqualTo(1);
        assertThat(productRepository.findById(product.getId()).orElseThrow().getSaleStatus())
                .isEqualTo(SaleStatus.SOLD);
        long charged = buyers.stream()
                .mapToLong(buyer -> 500_000L - pointService.getBalance(buyer.getId()).available())
                .sum();
        assertThat(charged).isEqualTo(price);
    }

    @Test
    void 잔액보다_많은_상품을_동시에_사면_잔액만큼만_성공하고_잔액과_원장이_맞는다() throws Exception {
        long price = 45_000L;
        Member buyer = 회원_생성("구매자");
        pointService.charge(buyer.getId(), 100_000L, null);
        List<Product> products = new ArrayList<>();
        for (int i = 0; i < 5; i++) {
            products.add(상품_등록(price));
        }

        List<Callable<Boolean>> tasks = products.stream()
                .<Callable<Boolean>>map(product -> () -> 구매(buyer.getId(), product.getId()))
                .toList();
        long succeeded = 동시에_실행(tasks);

        PointBalanceResponse balance = pointService.getBalance(buyer.getId());
        assertThat(succeeded).isEqualTo(2);
        assertThat(balance.available()).isEqualTo(10_000L);
        assertThat(balance.tradeEscrow()).isEqualTo(90_000L);
        assertThat(jdbcTemplate.queryForObject(
                "select coalesce(sum(-amount), 0) from point_transaction where member_id = ? and type = 'PAYMENT'",
                Long.class, buyer.getId())).isEqualTo(90_000L);
    }

    @Test
    void 같은_회원이_같은_상품을_연달아_눌러도_한_번만_결제된다() throws Exception {
        long price = 170_000L;
        Member buyer = 회원_생성("구매자");
        pointService.charge(buyer.getId(), 500_000L, null);
        Product product = 상품_등록(price);

        List<Callable<Boolean>> tasks = new ArrayList<>();
        for (int i = 0; i < 10; i++) {
            tasks.add(() -> 구매(buyer.getId(), product.getId()));
        }
        long succeeded = 동시에_실행(tasks);

        assertThat(succeeded).isEqualTo(1);
        assertThat(주문_수(product.getId())).isEqualTo(1);
        assertThat(pointService.getBalance(buyer.getId()).available()).isEqualTo(500_000L - price);
    }

    private boolean 구매(Long buyerId, Long productId) {
        try {
            orderService.createOrder(buyerId, new OrderCreateRequest(productId, null));
            return true;
        } catch (CustomException e) {
            assertThat(e.getErrorCode()).isIn(
                    ErrorCode.PRODUCT_NOT_AVAILABLE_FOR_PURCHASE, ErrorCode.INSUFFICIENT_POINTS);
            return false;
        }
    }

    private long 동시에_실행(List<Callable<Boolean>> tasks) throws Exception {
        ExecutorService executor = Executors.newFixedThreadPool(tasks.size());
        CountDownLatch start = new CountDownLatch(1);
        try {
            List<Future<Boolean>> futures = new ArrayList<>();
            for (Callable<Boolean> task : tasks) {
                futures.add(executor.submit(() -> {
                    start.await();
                    return task.call();
                }));
            }
            start.countDown();
            long succeeded = 0;
            for (Future<Boolean> future : futures) {
                if (future.get()) {
                    succeeded++;
                }
            }
            return succeeded;
        } finally {
            executor.shutdownNow();
        }
    }

    private long 주문_수(Long productId) {
        return jdbcTemplate.queryForObject("select count(*) from orders where product_id = ?", Long.class, productId);
    }

    private Product 상품_등록(long price) {
        Product product = Product.builder()
                .seller(seller)
                .categoryId(categoryId)
                .title("동시 구매 검증용 상품")
                .build();
        product.registerDirectSale(price);
        return productRepository.save(product);
    }

    private Member 회원_생성(String name) {
        Member member = memberRepository.save(Member.builder()
                .email("order-race-" + UUID.randomUUID() + "@example.com")
                .password("encoded")
                .name(name)
                .build());
        memberIds.add(member.getId());
        return member;
    }
}
