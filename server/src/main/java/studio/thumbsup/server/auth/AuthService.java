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
    private final Clock clock;

    public AuthService(
            UserRepository userRepository,
            RefreshTokenRepository refreshTokenRepository,
            PasswordEncoder passwordEncoder,
            JwtTokenProvider jwtTokenProvider,
            JwtProperties jwtProperties,
            Clock clock) {
        this.userRepository = userRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtTokenProvider = jwtTokenProvider;
        this.jwtProperties = jwtProperties;
        this.clock = clock;
    }

    @Transactional
    public AuthTokenResponse signup(SignupRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new BusinessException(AuthErrorType.USER_EMAIL_DUPLICATED);
        }
        User user = userRepository.save(User.create(request.email(), passwordEncoder.encode(request.password())));
        return issueTokens(user.getId());
    }

    @Transactional
    public AuthTokenResponse login(LoginRequest request) {
        User user = userRepository
                .findByEmail(request.email())
                .orElseThrow(() -> new BusinessException(AuthErrorType.INVALID_CREDENTIALS));
        if (!passwordEncoder.matches(request.password(), user.getPassword())) {
            throw new BusinessException(AuthErrorType.INVALID_CREDENTIALS);
        }
        return issueTokens(user.getId());
    }

    @Transactional
    public AuthTokenResponse refresh(RefreshRequest request) {
        RefreshToken stored = refreshTokenRepository
                .findByTokenHash(hash(request.refreshToken()))
                .orElseThrow(() -> new BusinessException(AuthErrorType.INVALID_REFRESH_TOKEN));
        if (stored.isExpired(clock)) {
            throw new BusinessException(AuthErrorType.INVALID_REFRESH_TOKEN);
        }
        return issueTokens(stored.getUserId());
    }

    @Transactional
    public void logout(Long userId) {
        refreshTokenRepository.deleteByUserId(userId);
    }

    private AuthTokenResponse issueTokens(Long userId) {
        String accessToken = jwtTokenProvider.createAccessToken(userId);
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

    private String hash(String rawToken) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(rawToken.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new BusinessException(CommonErrorType.INTERNAL_ERROR, e);
        }
    }
}
