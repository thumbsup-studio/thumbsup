/** 계정 권한. ADMIN만 /authoring(문제 저작 대시보드)에 접근 가능(이슈 176). */
export type Role = "USER" | "ADMIN";

/** 프로필 화면이 쓰는 프레젠테이션 데이터. 이메일과 권한(role)을 담는다. */
export type ProfileData = {
  email: string;
  role: Role;
};
