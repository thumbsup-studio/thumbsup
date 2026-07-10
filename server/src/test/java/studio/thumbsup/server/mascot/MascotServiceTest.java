package studio.thumbsup.server.mascot;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import studio.thumbsup.server.mascot.dto.MascotResponse;

/** Service 단위 테스트 — Spring 없이 Mockito로 포만감 증가·감소 로직만 검증한다 (피라미드 1층). */
@ExtendWith(MockitoExtension.class)
class MascotServiceTest {

    @Mock
    private MascotRepository mascotRepository;

    private static final Long USER_ID = 1L;
    private static final Instant FED_AT = Instant.parse("2026-07-01T00:00:00Z");

    private MascotService service(Instant now) {
        return new MascotService(mascotRepository, Clock.fixed(now, ZoneOffset.UTC));
    }

    @Nested
    @DisplayName("보리 조회")
    class GetMascot {

        @Test
        @DisplayName("행이 없는 신규 유저는 만실(100%) 기본값을 반환한다")
        void returns_full_default_for_new_user() {
            given(mascotRepository.findByUserId(USER_ID)).willReturn(Optional.empty());

            MascotResponse response = service(FED_AT).getMascot(USER_ID);

            assertThat(response.name()).isEqualTo("보리");
            assertThat(response.fullness()).isEqualTo(100);
        }

        @Test
        @DisplayName("경과일수만큼 하루 10%씩 감소한 현재 포만감을 반환한다")
        void returns_decayed_fullness() {
            Mascot mascot = MascotFixture.mascot(1L, USER_ID, 80, FED_AT);
            given(mascotRepository.findByUserId(USER_ID)).willReturn(Optional.of(mascot));
            Instant threeDaysLater = FED_AT.plusSeconds(3 * 24 * 3600);

            MascotResponse response = service(threeDaysLater).getMascot(USER_ID);

            assertThat(response.fullness()).isEqualTo(50); // 80 - 3*10
        }

        @Test
        @DisplayName("감소분이 0% 밑으로 내려가지 않는다")
        void does_not_go_below_zero() {
            Mascot mascot = MascotFixture.mascot(1L, USER_ID, 20, FED_AT);
            given(mascotRepository.findByUserId(USER_ID)).willReturn(Optional.of(mascot));
            Instant tenDaysLater = FED_AT.plusSeconds(10 * 24 * 3600);

            MascotResponse response = service(tenDaysLater).getMascot(USER_ID);

            assertThat(response.fullness()).isZero();
        }
    }

    @Nested
    @DisplayName("먹이 주기")
    class Feed {

        @Test
        @DisplayName("기존 행이 있으면 현재(감소 반영) 포만감에 20%를 더한다")
        void adds_twenty_percent_to_current_fullness() {
            Mascot mascot = MascotFixture.mascot(1L, USER_ID, 50, FED_AT);
            given(mascotRepository.findByUserIdForUpdate(USER_ID)).willReturn(Optional.of(mascot));
            Instant oneDayLater = FED_AT.plusSeconds(24 * 3600);

            MascotResponse response = service(oneDayLater).feed(USER_ID);

            // 50 - 10(하루 감소) + 20(먹이) = 60
            assertThat(response.fullness()).isEqualTo(60);
            verify(mascotRepository).save(mascot);
        }

        @Test
        @DisplayName("100%를 넘지 않도록 캡한다")
        void caps_at_hundred() {
            Mascot mascot = MascotFixture.mascot(1L, USER_ID, 90, FED_AT);
            given(mascotRepository.findByUserIdForUpdate(USER_ID)).willReturn(Optional.of(mascot));

            MascotResponse response = service(FED_AT).feed(USER_ID);

            assertThat(response.fullness()).isEqualTo(100); // 90+20=110 → 캡
        }

        @Test
        @DisplayName("행이 없는 최초 호출은 새로 만들어(100% 기본) 먹인다")
        void creates_row_on_first_feed() {
            given(mascotRepository.findByUserIdForUpdate(USER_ID)).willReturn(Optional.empty());
            given(mascotRepository.saveAndFlush(any(Mascot.class))).willReturn(Mascot.create(USER_ID, FED_AT));

            MascotResponse response = service(FED_AT).feed(USER_ID);

            assertThat(response.fullness()).isEqualTo(100); // 100 + 20 → 캡 100
        }
    }
}
