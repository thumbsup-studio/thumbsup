package studio.thumbsup.server.auth;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.time.Instant;
import java.util.HexFormat;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.auth.dto.AuthTokenResponse;
import studio.thumbsup.server.auth.dto.LoginRequest;
import studio.thumbsup.server.auth.dto.MeResponse;
import studio.thumbsup.server.auth.dto.RefreshRequest;
import studio.thumbsup.server.auth.dto.SignupRequest;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.exception.CommonErrorType;
import studio.thumbsup.server.common.security.JwtProperties;
import studio.thumbsup.server.common.security.JwtTokenProvider;

@Service
@Transactional(readOnly = true)
public class AuthService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;
    private final JwtProperties jwtProperties;
    private final AuthoringAdminProperties authoringAdminProperties;
    private final Clock clock;

    public AuthService(
            UserRepository userRepository,
            RefreshTokenRepository refreshTokenRepository,
            PasswordEncoder passwordEncoder,
            JwtTokenProvider jwtTokenProvider,
            JwtProperties jwtProperties,
            AuthoringAdminProperties authoringAdminProperties,
            Clock clock) {
        this.userRepository = userRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtTokenProvider = jwtTokenProvider;
        this.jwtProperties = jwtProperties;
        this.authoringAdminProperties = authoringAdminProperties;
        this.clock = clock;
    }

    @Transactional
    public AuthTokenResponse signup(SignupRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new BusinessException(AuthErrorType.USER_EMAIL_DUPLICATED);
        }
        User user = userRepository.save(User.create(request.email(), passwordEncoder.encode(request.password())));
        return issueTokens(user);
    }

    @Transactional
    public AuthTokenResponse login(LoginRequest request) {
        User user = userRepository
                .findByEmail(request.email())
                .orElseThrow(() -> new BusinessException(AuthErrorType.INVALID_CREDENTIALS));
        if (!passwordEncoder.matches(request.password(), user.getPassword())) {
            throw new BusinessException(AuthErrorType.INVALID_CREDENTIALS);
        }
        return issueTokens(user);
    }

    @Transactional
    public AuthTokenResponse refresh(RefreshRequest request) {
        RefreshToken stored = refreshTokenRepository
                .findByTokenHash(hash(request.refreshToken()))
                .orElseThrow(() -> new BusinessException(AuthErrorType.INVALID_REFRESH_TOKEN));
        if (stored.isExpired(clock)) {
            throw new BusinessException(AuthErrorType.INVALID_REFRESH_TOKEN);
        }
        User user = userRepository
                .findById(stored.getUserId())
                .orElseThrow(() -> new BusinessException(AuthErrorType.USER_NOT_FOUND));
        return issueTokens(user);
    }

    @Transactional
    public void logout(Long userId) {
        refreshTokenRepository.deleteByUserId(userId);
    }

    public MeResponse getMe(Long userId) {
        User user =
                userRepository.findById(userId).orElseThrow(() -> new BusinessException(AuthErrorType.USER_NOT_FOUND));
        return MeResponse.from(user);
    }

    /**
     * 토큰 발급의 유일한 통로 — 저작 관리자 사전 지정(#174 C1) self-heal도 여기서 함께 처리한다.
     * signup/login/refresh 어느 경로로 토큰이 나가든 admin-emails에 등록된 이메일이면 그 순간 ADMIN으로
     * 승격되고, 발급되는 access token에도 최신 role이 실린다.
     */
    private AuthTokenResponse issueTokens(User user) {
        selfHealAdminRole(user);
        Long userId = user.getId();
        String accessToken =
                jwtTokenProvider.createAccessToken(userId, user.getRole().name());
        String rawRefreshToken = jwtTokenProvider.createRefreshToken();
        String tokenHash = hash(rawRefreshToken);
        Instant expiresAt = clock.instant().plus(jwtProperties.refreshTokenValidity());
        RefreshToken refreshToken = refreshTokenRepository
                .findByUserId(userId)
                .map(existing -> existing.rotate(tokenHash, expiresAt))
                .orElseGet(() -> RefreshToken.create(userId, tokenHash, expiresAt));
        refreshTokenRepository.save(refreshToken);
        return AuthTokenResponse.of(accessToken, rawRefreshToken);
    }

    private void selfHealAdminRole(User user) {
        if (!user.isAdmin() && authoringAdminProperties.adminEmails().contains(user.getEmail())) {
            user.promoteToAdmin();
        }
    }

    private String hash(String rawToken) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(rawToken.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new BusinessException(CommonErrorType.INTERNAL_ERROR, e);
        }
    }
}
