package com.ssafy.backend.chat.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.ssafy.backend.chat.dto.response.ChatMessageResponse;
import com.ssafy.backend.chat.entity.ChatMessage;
import com.ssafy.backend.chat.entity.SenderType;
import com.ssafy.backend.chat.repository.ChatMessageRepository;
import com.ssafy.backend.global.exception.CustomException;
import com.ssafy.backend.global.exception.ErrorCode;
import com.ssafy.backend.live.entity.Live;
import com.ssafy.backend.live.repository.LiveRepository;
import com.ssafy.backend.member.entity.Member;
import com.ssafy.backend.member.repository.MemberRepository;
import java.time.LocalDateTime;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

/** {@link ChatMessageService} 단위 테스트 — 발언 저장 규칙을 본다. 브로드캐스트는 STOMP 통합 테스트가 본다. */
@ExtendWith(MockitoExtension.class)
class ChatMessageServiceTest {

    private static final Long LIVE_ID = 1L;
    private static final Long SENDER_ID = 2L;
    private static final Long HOST_ID = 3L;
    private static final LocalDateTime STARTED_AT = LocalDateTime.of(2026, 8, 7, 20, 0);

    @Mock
    private ChatMessageRepository chatMessageRepository;

    @Mock
    private LiveRepository liveRepository;

    @Mock
    private MemberRepository memberRepository;

    private ChatMessageService chatMessageService;

    @BeforeEach
    void setUp() {
        chatMessageService = new ChatMessageService(chatMessageRepository, liveRepository, memberRepository);
    }

    private Live live() {
        Member host = Member.builder().email("host@example.com").password("encoded").name("호스트").build();
        ReflectionTestUtils.setField(host, "id", HOST_ID);
        Live live = Live.openNow(host, "빈티지 데님 라이브", null, null, STARTED_AT);
        ReflectionTestUtils.setField(live, "id", LIVE_ID);
        return live;
    }

    private Member viewer() {
        Member member =
                Member.builder().email("viewer@example.com").password("encoded").name("시청자").build();
        ReflectionTestUtils.setField(member, "id", SENDER_ID);
        ReflectionTestUtils.setField(member, "nickname", "덕후");
        return member;
    }

    private void stubSaveReturnsArgumentWithId(Long messageId) {
        when(chatMessageRepository.save(any(ChatMessage.class))).thenAnswer(invocation -> {
            ChatMessage message = invocation.getArgument(0);
            ReflectionTestUtils.setField(message, "id", messageId);
            return message;
        });
    }

    @Test
    void 회원_발언을_저장하고_브로드캐스트할_메시지를_돌려준다() {
        when(liveRepository.findById(LIVE_ID)).thenReturn(Optional.of(live()));
        when(memberRepository.findById(SENDER_ID)).thenReturn(Optional.of(viewer()));
        stubSaveReturnsArgumentWithId(10L);

        ChatMessageResponse message = chatMessageService.send(SENDER_ID, LIVE_ID, "사이즈 M 맞나요?", "tmp-1");

        assertThat(message.messageId()).isEqualTo(10L);
        assertThat(message.senderType()).isEqualTo(SenderType.USER);
        assertThat(message.senderNickname()).isEqualTo("덕후");
        assertThat(message.content()).isEqualTo("사이즈 M 맞나요?");
        // 발행자가 낙관적으로 그린 말풍선을 치환할 수 있게 임시 ID 를 그대로 돌려준다.
        assertThat(message.clientMessageId()).isEqualTo("tmp-1");
    }

    @Test
    void 앞뒤_공백을_지우고_저장한다() {
        when(liveRepository.findById(LIVE_ID)).thenReturn(Optional.of(live()));
        when(memberRepository.findById(SENDER_ID)).thenReturn(Optional.of(viewer()));
        stubSaveReturnsArgumentWithId(11L);

        ChatMessageResponse message = chatMessageService.send(SENDER_ID, LIVE_ID, "  안녕하세요  ", "tmp-2");

        assertThat(message.content()).isEqualTo("안녕하세요");
    }

    @Test
    void 비회원_발언은_저장하지_않고_거부한다() {
        assertThatThrownBy(() -> chatMessageService.send(null, LIVE_ID, "비회원 발언", "tmp-3"))
                .isInstanceOf(CustomException.class)
                .extracting(e -> ((CustomException) e).getErrorCode())
                .isEqualTo(ErrorCode.CHAT_GUEST_NOT_ALLOWED);
        verify(chatMessageRepository, never()).save(any());
    }
}
