package com.ssafy.backend.point.repository;

import com.ssafy.backend.point.entity.PointCharge;
import jakarta.persistence.LockModeType;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PointChargeRepository extends JpaRepository<PointCharge, Long> {

    Optional<PointCharge> findByOrderId(String orderId);

    /** 같은 충전 건의 승인 요청이 동시에 와도 한 번만 적립되도록 행을 잠근다. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select c from PointCharge c where c.orderId = :orderId")
    Optional<PointCharge> findByOrderIdForUpdate(@Param("orderId") String orderId);
}