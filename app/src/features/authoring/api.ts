import { apiRequest } from "@/lib/api";
import type {
  AuthoringCourse,
  AuthoringCourseDetail,
  AuthoringStep,
  DraftDetail,
  DraftSummary,
  JobStatus,
  OutlineDetail,
  OutlineSummary,
  QuizPreset,
} from "./types";

export function generateDraft(topic: string): Promise<{ jobId: number }> {
  return apiRequest("/authoring/drafts/generate", { method: "POST", body: { topic } });
}

export function createOutline(
  title: string,
  category: string,
  toc: string,
): Promise<{ outlineId: number; jobId: number }> {
  return apiRequest("/authoring/outlines", {
    method: "POST",
    body: { title, category, toc },
  });
}

export async function getOutlines(): Promise<OutlineSummary[]> {
  const data = await apiRequest<{ outlines: OutlineSummary[] }>("/authoring/outlines");
  return data.outlines;
}

export function getOutline(outlineId: number): Promise<OutlineDetail> {
  return apiRequest(`/authoring/outlines/${outlineId}`);
}

export async function updateOutline(
  outlineId: number,
  body: { title?: string; category?: string },
): Promise<void> {
  await apiRequest<null>(`/authoring/outlines/${outlineId}`, { method: "PATCH", body });
}

export function regenerateOutline(outlineId: number): Promise<{ jobId: number }> {
  return apiRequest(`/authoring/outlines/${outlineId}/outline-jobs`, { method: "POST" });
}

export function publishOutline(
  outlineId: number,
): Promise<{ courseId: number; stepCount: number }> {
  return apiRequest(`/authoring/outlines/${outlineId}/publish`, { method: "POST" });
}

export function addOutlineStep(outlineId: number, topic: string): Promise<{ stepId: number }> {
  return apiRequest(`/authoring/outlines/${outlineId}/steps`, {
    method: "POST",
    body: { topic },
  });
}

export async function updateOutlineStep(stepId: number, topic: string): Promise<void> {
  await apiRequest<null>(`/authoring/outline-steps/${stepId}`, {
    method: "PATCH",
    body: { topic },
  });
}

export async function deleteOutlineStep(stepId: number): Promise<void> {
  await apiRequest<null>(`/authoring/outline-steps/${stepId}`, { method: "DELETE" });
}

export async function reorderOutlineStep(stepId: number, direction: "UP" | "DOWN"): Promise<void> {
  await apiRequest<null>(`/authoring/outline-steps/${stepId}/order`, {
    method: "PATCH",
    body: { direction },
  });
}

export function generateStepQuizzes(
  stepId: number,
  preset: QuizPreset,
): Promise<{ jobId: number }> {
  return apiRequest(`/authoring/outline-steps/${stepId}/generate`, {
    method: "POST",
    body: { preset },
  });
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
