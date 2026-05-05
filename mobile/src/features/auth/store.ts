import {create} from 'zustand';
import {MMKV} from 'react-native-mmkv';

const storage = new MMKV({id: 'auth'});

interface AuthState {
  token: string | null;
  userId: string | null;
  setAuth: (token: string, userId: string) => void;
  clearAuth: () => void;
}

export const useAuthStore = create<AuthState>(set => ({
  token: storage.getString('token') ?? null,
  userId: storage.getString('userId') ?? null,

  setAuth(token, userId) {
    storage.set('token', token);
    storage.set('userId', userId);
    set({token, userId});
  },

  clearAuth() {
    storage.delete('token');
    storage.delete('userId');
    set({token: null, userId: null});
  },
}));
