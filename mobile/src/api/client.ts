import {useAuthStore} from '@/features/auth/store';

const BASE_URL = __DEV__
  ? 'http://localhost:4000/api'
  : 'https://api.portermills.app/api';

async function request<T>(
  path: string,
  options: RequestInit = {},
): Promise<T> {
  const token = useAuthStore.getState().token;
  const res = await fetch(`${BASE_URL}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? {Authorization: `Bearer ${token}`} : {}),
      ...options.headers,
    },
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`API ${res.status}: ${body}`);
  }

  return res.json() as Promise<T>;
}

export const api = {
  get: <T>(path: string) => request<T>(path),
  post: <T>(path: string, body: unknown) =>
    request<T>(path, {method: 'POST', body: JSON.stringify(body)}),
  patch: <T>(path: string, body: unknown) =>
    request<T>(path, {method: 'PATCH', body: JSON.stringify(body)}),
  delete: <T>(path: string) => request<T>(path, {method: 'DELETE'}),
};
