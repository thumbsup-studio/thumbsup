import { apiRequest } from "@/lib/api";
import type {
  AuthoringCourse,
  AuthoringCourseDetail,
  AuthoringStep,
  DraftDetail,
  DraftSummary,
  JobStatus,
} from "./types";

export function generateDraft(topic: string): Promise<{ jobId: number }> {
  return apiRequest("/authoring/drafts/generate", { method: "POST", body: { topic } });
}

export function improveQuiz(
  quizId: number,
  instruction: string,
): Promise<{ draftId: number; jobId: number }> {
  return apiRequest(`/authoring/quizzes/${quizId}/improve`, {
    method: "POST",
    body: { instruction },
  });
}

export function reviewDraft(draftId: number, feedback?: string): Promise<{ jobId: number }> {
  return apiRequest(`/authoring/drafts/${draftId}/reviews`, {
    method: "POST",
    body: feedback === undefined ? {} : { feedback },
  });
}

export function approveDraft(draftId: number): Promise<{ draftId: number; status: string }> {
  return apiRequest(`/authoring/drafts/${draftId}/approve`, { method: "POST" });
}

export async function getDrafts(status?: "DRAFT" | "APPROVED"): Promise<DraftSummary[]> {
  const query = status ? `?status=${status}` : "";
  const data = await apiRequest<{ drafts: DraftSummary[] }>(`/authoring/drafts${query}`);
  return data.drafts;
}

export function getDraft(draftId: number): Promise<DraftDetail> {
  return apiRequest(`/authoring/drafts/${draftId}`);
}

export async function getAuthoringQuizzes(): Promise<AuthoringStep[]> {
  const data = await apiRequest<{ steps: AuthoringStep[] }>("/authoring/quizzes");
  return data.steps;
}

export function getJob(jobId: number): Promise<JobStatus> {
  return apiRequest(`/authoring/jobs/${jobId}`);
}

export async function getAuthoringCourses(): Promise<AuthoringCourse[]> {
  const data = await apiRequest<{ courses: AuthoringCourse[] }>("/authoring/courses");
  return data.courses;
}

export function getAuthoringCourseQuizzes(courseId: number): Promise<AuthoringCourseDetail> {
  return apiRequest(`/authoring/courses/${courseId}/quizzes`);
}
