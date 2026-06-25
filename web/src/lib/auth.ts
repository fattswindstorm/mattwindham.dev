// Recruiter portal auth helpers - talks to Cognito directly via fetch (no
// AWS SDK / Amplify dependency, consistent with this project's near-zero
// `package.json`). Handles email/password auth against the Cognito
// Identity Provider API, the Google Hosted UI handshake via Authorization
// Code + PKCE, and local token storage/refresh.

import {
  COGNITO_CLIENT_ID,
  COGNITO_IDP_ENDPOINT,
  COGNITO_HOSTED_UI_DOMAIN,
  COGNITO_CALLBACK_URL,
} from "./cognito-config";

const STORAGE_KEY = "portal_tokens";
const PKCE_KEY = "portal_pkce";
const EXPIRY_SKEW_MS = 30_000;

interface Tokens {
  idToken: string;
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
}

export interface Claims {
  sub: string;
  email?: string;
  name?: string;
  "cognito:groups"?: string;
}

export class CognitoError extends Error {
  code: string;
  constructor(message: string, code: string) {
    super(message);
    this.code = code;
  }
}

function base64UrlEncode(bytes: Uint8Array): string {
  let str = "";
  bytes.forEach((b) => (str += String.fromCharCode(b)));
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function randomString(length = 64): string {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return base64UrlEncode(bytes).slice(0, length);
}

async function sha256(input: string): Promise<Uint8Array> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return new Uint8Array(digest);
}

function decodeJwt(token: string): Record<string, unknown> {
  const payload = token.split(".")[1];
  const json = atob(payload.replace(/-/g, "+").replace(/_/g, "/"));
  return JSON.parse(json);
}

function storeTokens(t: Tokens) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(t));
}

function readTokens(): Tokens | null {
  const raw = localStorage.getItem(STORAGE_KEY);
  return raw ? JSON.parse(raw) : null;
}

export function clearTokens() {
  localStorage.removeItem(STORAGE_KEY);
}

function applyAuthResult(
  result: { AccessToken: string; IdToken: string; RefreshToken?: string; ExpiresIn: number },
  fallbackRefreshToken?: string
) {
  const refreshToken = result.RefreshToken ?? fallbackRefreshToken;
  if (!refreshToken) throw new CognitoError("No refresh token returned", "MissingRefreshToken");
  storeTokens({
    idToken: result.IdToken,
    accessToken: result.AccessToken,
    refreshToken,
    expiresAt: Date.now() + result.ExpiresIn * 1000,
  });
}

async function idpRequest(target: string, body: Record<string, unknown>) {
  const res = await fetch(COGNITO_IDP_ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-amz-json-1.1",
      "X-Amz-Target": `AWSCognitoIdentityProviderService.${target}`,
    },
    body: JSON.stringify(body),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const type = (json.__type || "UnknownError").split("#").pop();
    throw new CognitoError(json.message || type, type);
  }
  return json;
}

export async function signUp(name: string, email: string, password: string) {
  return idpRequest("SignUp", {
    ClientId: COGNITO_CLIENT_ID,
    Username: email,
    Password: password,
    UserAttributes: [
      { Name: "email", Value: email },
      { Name: "name", Value: name },
    ],
  });
}

export async function confirmSignUp(email: string, code: string) {
  return idpRequest("ConfirmSignUp", {
    ClientId: COGNITO_CLIENT_ID,
    Username: email,
    ConfirmationCode: code,
  });
}

export async function resendConfirmationCode(email: string) {
  return idpRequest("ResendConfirmationCode", {
    ClientId: COGNITO_CLIENT_ID,
    Username: email,
  });
}

export async function signInWithPassword(email: string, password: string) {
  const result = await idpRequest("InitiateAuth", {
    AuthFlow: "USER_PASSWORD_AUTH",
    ClientId: COGNITO_CLIENT_ID,
    AuthParameters: { USERNAME: email, PASSWORD: password },
  });
  applyAuthResult(result.AuthenticationResult);
}

// --- Google sign-in via Hosted UI (Authorization Code + PKCE) ---

export async function redirectToGoogleSignIn(next?: string) {
  const verifier = randomString(64);
  const challenge = base64UrlEncode(await sha256(verifier));
  const state = randomString(32);
  sessionStorage.setItem(PKCE_KEY, JSON.stringify({ verifier, state, next }));

  const params = new URLSearchParams({
    identity_provider: "Google",
    redirect_uri: COGNITO_CALLBACK_URL,
    response_type: "code",
    client_id: COGNITO_CLIENT_ID,
    scope: "openid email profile",
    code_challenge: challenge,
    code_challenge_method: "S256",
    state,
  });

  window.location.href = `https://${COGNITO_HOSTED_UI_DOMAIN}/oauth2/authorize?${params}`;
}

export async function handleOAuthCallback(): Promise<string | undefined> {
  const url = new URL(window.location.href);
  const error = url.searchParams.get("error");
  if (error) throw new Error(url.searchParams.get("error_description") || error);

  const code = url.searchParams.get("code");
  if (!code) throw new Error("Missing authorization code");

  const saved = sessionStorage.getItem(PKCE_KEY);
  if (!saved) throw new Error("Missing sign-in state - please try again");
  const { verifier, state: savedState, next } = JSON.parse(saved);
  sessionStorage.removeItem(PKCE_KEY);
  if (url.searchParams.get("state") !== savedState) {
    throw new Error("State mismatch - please try signing in again");
  }

  const res = await fetch(`https://${COGNITO_HOSTED_UI_DOMAIN}/oauth2/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "authorization_code",
      client_id: COGNITO_CLIENT_ID,
      code,
      redirect_uri: COGNITO_CALLBACK_URL,
      code_verifier: verifier,
    }),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(json.error_description || json.error || "Sign-in failed");

  storeTokens({
    idToken: json.id_token,
    accessToken: json.access_token,
    refreshToken: json.refresh_token,
    expiresAt: Date.now() + json.expires_in * 1000,
  });

  return next as string | undefined;
}

// --- Session ---

async function refresh(tokens: Tokens): Promise<Tokens> {
  const result = await idpRequest("InitiateAuth", {
    AuthFlow: "REFRESH_TOKEN_AUTH",
    ClientId: COGNITO_CLIENT_ID,
    AuthParameters: { REFRESH_TOKEN: tokens.refreshToken },
  });
  applyAuthResult(result.AuthenticationResult, tokens.refreshToken);
  return readTokens()!;
}

async function getValidTokens(): Promise<Tokens | null> {
  let tokens = readTokens();
  if (!tokens) return null;
  if (Date.now() > tokens.expiresAt - EXPIRY_SKEW_MS) {
    try {
      tokens = await refresh(tokens);
    } catch {
      clearTokens();
      return null;
    }
  }
  return tokens;
}

export async function getClaims(): Promise<Claims | null> {
  const tokens = await getValidTokens();
  return tokens ? (decodeJwt(tokens.idToken) as Claims) : null;
}

export function isAdmin(claims: Claims | null): boolean {
  return !!claims && (claims["cognito:groups"] || "").includes("admins");
}

export async function requireAuth(next?: string): Promise<Claims | null> {
  const claims = await getClaims();
  if (!claims) {
    const qs = next ? `?next=${encodeURIComponent(next)}` : "";
    window.location.href = `/portal/login${qs}`;
    return null;
  }
  return claims;
}

export async function authHeader(): Promise<Record<string, string>> {
  const tokens = await getValidTokens();
  if (!tokens) throw new Error("Not authenticated");
  return { Authorization: `Bearer ${tokens.idToken}` };
}

export function signOut() {
  clearTokens();
  window.location.href = "/portal/login";
}
