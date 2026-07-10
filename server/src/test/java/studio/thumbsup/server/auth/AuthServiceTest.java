package studio.thumbsup.server.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.HexFormat;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;
import studio.thumbsup.server.auth.dto.AuthTokenResponse;
import studio.thumbsup.server.auth.dto.LoginRequest;
import studio.thumbsup.server.auth.dto.RefreshRequest;
import studio.thumbsup.server.auth.dto.SignupRequest;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.security.JwtProperties;
import studio.thumbsup.server.common.security.JwtTokenProvider;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-07T00:00:00Z");

    @Mock
    private UserRepository userRepository;

    @Mock
    private RefreshTokenRepository refreshTokenRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private JwtTokenProvider jwtTokenProvider;

    private AuthService authService;

    @BeforeEach
    void setUp() {
        JwtProperties jwtProperties = new JwtProperties("test-secret", Duration.ofMinutes(30), Duration.ofDays(14));
        Clock clock = Clock.fixed(NOW, ZoneOffset.UTC);
        authService = new AuthService(
                userRepository, refreshTokenRepository, passwordEncoder, jwtTokenProvider, jwtProperties, clock);
    }

    @Test
    void 이메일이_중복이면_USER_EMAIL_DUPLICATED() {
        given(userRepository.existsByEmail("a@test.com")).willReturn(true);

        assertThatThrownBy(() -> authService.signup(new SignupRequest("a@test.com", "password1")))
                .isInstanceOf(BusinessException.class)
                .satisfies(e -> assertThat(((BusinessException) e).getErrorType())
                        .isEqualTo(AuthErrorType.USER_EMAIL_DUPLICATED));
    }

    @Test
    void 회원가입_성공시_유저를_생성하고_신규_토큰을_발급한다() {
        given(userRepository.existsByEmail("a@test.com")).willReturn(false);
        given(passwordEncoder.encode("password1")).willReturn("hashed");
        given(userRepository.save(any(User.class))).willReturn(AuthFixture.user(1L, "a@test.com", "hashed"));
        given(refreshTokenRepository.findByUserId(1L)).willReturn(Optional.empty());
        given(jwtTokenProvider.createAccessToken(1L)).willReturn("access-token");
        given(jwtTokenProvider.createRefreshToken()).willReturn("raw-refresh-token");

        AuthTokenResponse response = authService.signup(new SignupRequest("a@test.com", "password1"));

        assertThat(response.accessToken()).isEqualTo("access-token");
        assertThat(response.refreshToken()).isNotBlank();

        ArgumentCaptor<RefreshToken> refreshTokenCaptor = ArgumentCaptor.forClass(RefreshToken.class);
        verify(refreshTokenRepository).save(refreshTokenCaptor.capture());
        RefreshToken savedRefreshToken = refreshTokenCaptor.getValue();

        String expectedHash = sha256Hex(response.refreshToken());
        assertThat(savedRefreshToken.getTokenHash()).hasSize(64).matches("[0-9a-f]{64}");
        assertThat(savedRefreshToken.getTokenHash()).isEqualTo(expectedHash);
        assertThat(savedRefreshToken.getTokenHash()).isNotEqualTo(response.refreshToken());
        assertThat(savedRefreshToken.getExpiresAt()).isEqualTo(NOW.plus(Duration.ofDays(14)));
    }

    private static String sha256Hex(String rawToken) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(rawToken.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    @Test
    void 존재하지_않는_이메일로_로그인하면_INVALID_CREDENTIALS() {
        given(userRepository.findByEmail("nobody@test.com")).willReturn(Optional.empty());

        assertThatThrownBy(() -> authService.login(new LoginRequest("nobody@test.com", "password1")))
                .isInstanceOf(BusinessException.class)
                .satisfies(e -> assertThat(((BusinessException) e).getErrorType())
                        .isEqualTo(AuthErrorType.INVALID_CREDENTIALS));
    }

    @Test
    void 비밀번호가_틀리면_INVALID_CREDENTIALS() {
        User user = AuthFixture.user(1L, "a@test.com", "hashed");
        given(userRepository.findByEmail("a@test.com")).willReturn(Optional.of(user));
        given(passwordEncoder.matches("wrong", "hashed")).willReturn(false);

        assertThatThrownBy(() -> authService.login(new LoginRequest("a@test.com", "wrong")))
                .isInstanceOf(BusinessException.class)
                .satisfies(e -> assertThat(((BusinessException) e).getErrorType())
                        .isEqualTo(AuthErrorType.INVALID_CREDENTIALS));
    }

    @Test
    void 로그인_성공시_토큰을_발급한다() {
        User user = AuthFixture.user(1L, "a@test.com", "hashed");
        given(userRepository.findByEmail("a@test.com")).willReturn(Optional.of(user));
        given(passwordEncoder.matches("password1", "hashed")).willReturn(true);
        given(refreshTokenRepository.findByUserId(1L)).willReturn(Optional.empty());
        given(jwtTokenProvider.createAccessToken(1L)).willReturn("access-token");
        given(jwtTokenProvider.createRefreshToken()).willReturn("raw-refresh-token");

        AuthTokenResponse response = authService.login(new LoginRequest("a@test.com", "password1"));

        assertThat(response.accessToken()).isEqualTo("access-token");
        assertThat(response.refreshToken()).isNotBlank();
    }

    @Test
    void 로그인_성공시_기존_refresh_token이_있으면_회전한다() {
        User user = AuthFixture.user(1L, "a@test.com", "hashed");
        RefreshToken existing = AuthFixture.refreshToken(9L, 1L, "old-hash", NOW.plus(Duration.ofDays(1)));
        given(userRepository.findByEmail("a@test.com")).willReturn(Optional.of(user));
        given(passwordEncoder.matches("password1", "hashed")).willReturn(true);
        given(refreshTokenRepository.findByUserId(1L)).willReturn(Optional.of(existing));
        given(jwtTokenProvider.createAccessToken(1L)).willReturn("access-token");
        given(jwtTokenProvider.createRefreshToken()).willReturn("raw-refresh-token");

        AuthTokenResponse response = authService.login(new LoginRequest("a@test.com", "password1"));

        ArgumentCaptor<RefreshToken> refreshTokenCaptor = ArgumentCaptor.forClass(RefreshToken.class);
        verify(refreshTokenRepository).save(refreshTokenCaptor.capture());
        RefreshToken savedRefreshToken = refreshTokenCaptor.getValue();

        assertThat(savedRefreshToken.getId()).isEqualTo(9L);
        assertThat(savedRefreshToken.getTokenHash()).isEqualTo(sha256Hex(response.refreshToken()));
    }

    @Test
    void 존재하지_않는_refresh_token은_INVALID_REFRESH_TOKEN() {
        given(refreshTokenRepository.findByTokenHash(any())).willReturn(Optional.empty());

        assertThatThrownBy(() -> authService.refresh(new RefreshRequest("raw-token")))
                .isInstanceOf(BusinessException.class)
                .satisfies(e -> assertThat(((BusinessException) e).getErrorType())
                        .isEqualTo(AuthErrorType.INVALID_REFRESH_TOKEN));
    }

    @Test
    void 만료된_refresh_token은_INVALID_REFRESH_TOKEN() {
        RefreshToken expired = AuthFixture.refreshToken(1L, 1L, "hash", NOW.minus(Duration.ofDays(1)));
        given(refreshTokenRepository.findByTokenHash(any())).willReturn(Optional.of(expired));

        assertThatThrownBy(() -> authService.refresh(new RefreshRequest("raw-token")))
                .isInstanceOf(BusinessException.class)
                .satisfies(e -> assertThat(((BusinessException) e).getErrorType())
                        .isEqualTo(AuthErrorType.INVALID_REFRESH_TOKEN));
    }

    @Test
    void refresh_성공시_기존_토큰을_회전하고_신규_토큰을_발급한다() {
        RefreshToken valid = AuthFixture.refreshToken(1L, 7L, "hash", NOW.plus(Duration.ofDays(1)));
        given(refreshTokenRepository.findByTokenHash(any())).willReturn(Optional.of(valid));
        given(refreshTokenRepository.findByUserId(7L)).willReturn(Optional.of(valid));
        given(jwtTokenProvider.createAccessToken(7L)).willReturn("new-access-token");
        given(jwtTokenProvider.createRefreshToken()).willReturn("new-raw-refresh-token");

        AuthTokenResponse response = authService.refresh(new RefreshRequest("raw-token"));

        assertThat(response.accessToken()).isEqualTo("new-access-token");
        assertThat(response.refreshToken()).isNotBlank();

        ArgumentCaptor<RefreshToken> refreshTokenCaptor = ArgumentCaptor.forClass(RefreshToken.class);
        verify(refreshTokenRepository).save(refreshTokenCaptor.capture());
        RefreshToken savedRefreshToken = refreshTokenCaptor.getValue();

        String expectedHash = sha256Hex(response.refreshToken());
        assertThat(savedRefreshToken.getId()).isEqualTo(1L);
        assertThat(savedRefreshToken.getTokenHash()).hasSize(64).matches("[0-9a-f]{64}");
        assertThat(savedRefreshToken.getTokenHash()).isEqualTo(expectedHash);
        assertThat(savedRefreshToken.getTokenHash()).isNotEqualTo(response.refreshToken());
        assertThat(savedRefreshToken.getExpiresAt()).isEqualTo(NOW.plus(Duration.ofDays(14)));
    }

    @Test
    void logout은_유저의_refresh_token을_모두_삭제한다() {
        authService.logout(7L);

        verify(refreshTokenRepository).deleteByUserId(7L);
    }

    @Test
    void 내_정보_조회시_토큰의_userId로_유저를_찾아_이메일을_반환한다() {
        given(userRepository.findById(7L)).willReturn(Optional.of(AuthFixture.user(7L, "a@test.com", "hashed")));

        assertThat(authService.getMe(7L).email()).isEqualTo("a@test.com");
    }

    @Test
    void 없는_유저의_내_정보_조회는_USER_NOT_FOUND() {
        given(userRepository.findById(99L)).willReturn(Optional.empty());

        assertThatThrownBy(() -> authService.getMe(99L))
                .isInstanceOf(BusinessException.class)
                .satisfies(e ->
                        assertThat(((BusinessException) e).getErrorType()).isEqualTo(AuthErrorType.USER_NOT_FOUND));
    }
}
