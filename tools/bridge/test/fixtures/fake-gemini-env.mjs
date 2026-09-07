#!/usr/bin/env node
// 자식 프로세스가 GEMINI_API_KEY·GOOGLE_API_KEY를 실제로 못 보는지 결과로 echo하는 변형.
const hasGeminiKey = process.env.GEMINI_API_KEY !== undefined;
const hasGoogleKey = process.env.GOOGLE_API_KEY !== undefined;
process.stdout.write(JSON.stringify({ response: JSON.stringify({ hasGeminiKey, hasGoogleKey }) }));
