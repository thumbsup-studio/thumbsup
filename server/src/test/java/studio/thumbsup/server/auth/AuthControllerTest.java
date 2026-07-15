package studio.thumbsup.server.auth;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.MediaType;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.method.annotation.AuthenticationPrincipalArgumentResolver;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import studio.thumbsup.server.auth.dto.AuthTokenResponse;
import studio.thumbsup.server.auth.dto.LoginRequest;
import studio.thumbsup.server.auth.dto.MeResponse;
import studio.thumbsup.server.auth.dto.RefreshRequest;
import studio.thumbsup.server.auth.dto.SignupRequest;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.exception.GlobalExceptionHandler;

/** Controller 슬라이스 테스트 — standalone MockMvc로 요청/응답 계약만 검증한다 (피라미드 2층). */
@ExtendWith(MockitoExtension.class)
class AuthControllerTest {

    @Mock
    private AuthService authService;

    private MockMvc mockMvc;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @BeforeEach
    void setUp() {
        // @AuthenticationPrincipal 해석기를 명시 등록 — standalone은 Boot 자동설정이 없어 기본 등록되지 않는다
        mockMvc = MockMvcBuilders.standaloneSetup(new AuthController(authService))
                .setControllerAdvice(new GlobalExceptionHandler())
                .setMessageConverters(new MappingJackson2HttpMessageConverter(objectMapper))
                .setCustomArgumentResolvers(new AuthenticationPrincipalArgumentResolver())
                .build();
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void 회원가입_성공시_201과_토큰을_반환한다() throws Exception {
        given(authService.signup(any())).willReturn(new AuthTokenResponse("access-token", "refresh-token"));

        mockMvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new SignupRequest("a@test.com", "password1"))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.code").value("SUCCESS"))
                .andExpect(jsonPath("$.data.accessToken").value("access-token"))
                .andExpect(jsonPath("$.data.refreshToken").value("refresh-token"));
    }

    @Test
    void 이메일_형식이_아니면_INVALID_INPUT() throws Exception {
        mockMvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new SignupRequest("not-an-email", "password1"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_INPUT"));
    }

    @Test
    void 비밀번호가_8자_미만이면_INVALID_INPUT() throws Exception {
        mockMvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new SignupRequest("a@test.com", "short"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_INPUT"));
    }

    @Test
    void 이메일이_중복이면_409_USER_EMAIL_DUPLICATED() throws Exception {
        given(authService.signup(any())).willThrow(new BusinessException(AuthErrorType.USER_EMAIL_DUPLICATED));

        mockMvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new SignupRequest("a@test.com", "password1"))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("USER_EMAIL_DUPLICATED"));
    }

    @Test
    void 로그인_성공시_200과_토큰을_반환한다() throws Exception {
        given(authService.login(any())).willReturn(new AuthTokenResponse("access-token", "refresh-token"));

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new LoginRequest("a@test.com", "password1"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.accessToken").value("access-token"));
    }

    @Test
    void 로그인_실패시_401_INVALID_CREDENTIALS() throws Exception {
        given(authService.login(any())).willThrow(new BusinessException(AuthErrorType.INVALID_CREDENTIALS));

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new LoginRequest("a@test.com", "wrong"))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"));
    }

    @Test
    void refresh_성공시_200과_회전된_토큰을_반환한다() throws Exception {
        given(authService.refresh(any())).willReturn(new AuthTokenResponse("new-access", "new-refresh"));

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new RefreshRequest("old-refresh"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.accessToken").value("new-access"));
    }

    @Test
    void refresh_실패시_401_INVALID_REFRESH_TOKEN() throws Exception {
        given(authService.refresh(any())).willThrow(new BusinessException(AuthErrorType.INVALID_REFRESH_TOKEN));

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new RefreshRequest("invalid"))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_REFRESH_TOKEN"));
    }

    @Test
    void logout은_토큰의_userId로_서비스를_호출하고_200을_반환한다() throws Exception {
        // JwtAuthenticationFilter가 SecurityContext에 심는 것과 동일한 형태로 인증 컨텍스트를 미리 채운다
        SecurityContextHolder.getContext()
                .setAuthentication(new UsernamePasswordAuthenticationToken(7L, null, List.of()));

        mockMvc.perform(post("/api/v1/auth/logout"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value("SUCCESS"))
                .andExpect(jsonPath("$.data").doesNotExist());

        verify(authService).logout(7L);
    }

    @Test
    void 내_정보_조회시_토큰의_userId로_서비스를_호출하고_이메일을_반환한다() throws Exception {
        SecurityContextHolder.getContext()
                .setAuthentication(new UsernamePasswordAuthenticationToken(7L, null, List.of()));
        given(authService.getMe(7L)).willReturn(new MeResponse("a@test.com", "USER"));

        mockMvc.perform(get("/api/v1/auth/me"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value("SUCCESS"))
                .andExpect(jsonPath("$.data.email").value("a@test.com"))
                .andExpect(jsonPath("$.data.role").value("USER"));
    }

    @Test
    void 없는_유저의_내_정보_조회는_404_USER_NOT_FOUND() throws Exception {
        SecurityContextHolder.getContext()
                .setAuthentication(new UsernamePasswordAuthenticationToken(99L, null, List.of()));
        given(authService.getMe(99L)).willThrow(new BusinessException(AuthErrorType.USER_NOT_FOUND));

        mockMvc.perform(get("/api/v1/auth/me"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("USER_NOT_FOUND"));
    }
}
