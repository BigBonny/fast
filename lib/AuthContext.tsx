"use client";

import React, { createContext, useState, useContext, useEffect, useCallback, ReactNode } from "react";
import { authApi, getToken, setToken, UNAUTHORIZED_EVENT, type RegisterPayload } from "@/api/fastBackend";
import { clearCart } from "@/lib/localCart";
import type { ApiError, User } from "@/lib/types";

interface AuthError {
  type: string;
  message: string;
}

interface AuthContextType {
  user: User | null;
  isAuthenticated: boolean;
  isLoadingAuth: boolean;
  authError: AuthError | null;
  login: (email: string, password: string) => Promise<User>;
  register: (data: RegisterPayload) => Promise<User>;
  logout: (shouldRedirect?: boolean) => Promise<void>;
  navigateToLogin: () => void;
  checkAppState: () => Promise<void>;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider = ({ children }: { children: ReactNode }) => {
  const [user, setUser] = useState<User | null>(null);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoadingAuth, setIsLoadingAuth] = useState(true);
  const [authError, setAuthError] = useState<AuthError | null>(null);

  const checkUserAuth = useCallback(async () => {
    try {
      setIsLoadingAuth(true);
      const currentUser = await authApi.me();
      setUser(currentUser);
      setIsAuthenticated(true);
    } catch (error) {
      const status = (error as ApiError)?.status;
      setIsAuthenticated(false);
      setUser(null);
      if (status === 401 || status === 403) {
        setToken(null);
        setAuthError({ type: "auth_required", message: "Authentication required" });
      }
    } finally {
      setIsLoadingAuth(false);
    }
  }, []);

  const checkAppState = useCallback(async () => {
    setAuthError(null);
    if (!getToken()) {
      setIsAuthenticated(false);
      setUser(null);
      setIsLoadingAuth(false);
      return;
    }
    await checkUserAuth();
  }, [checkUserAuth]);

  useEffect(() => {
    void checkAppState();
  }, [checkAppState]);

  // Any 401 from the API client invalidates the session app-wide.
  useEffect(() => {
    const onUnauthorized = () => {
      setUser(null);
      setIsAuthenticated(false);
      setAuthError({ type: "auth_required", message: "Session expirée" });
    };
    window.addEventListener(UNAUTHORIZED_EVENT, onUnauthorized);
    return () => window.removeEventListener(UNAUTHORIZED_EVENT, onUnauthorized);
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    setAuthError(null);
    setIsLoadingAuth(true);
    try {
      await authApi.login({ email, password });
      const currentUser = await authApi.me();
      setUser(currentUser);
      setIsAuthenticated(true);
      return currentUser;
    } finally {
      setIsLoadingAuth(false);
    }
  }, []);

  const register = useCallback(async (data: RegisterPayload) => {
    setAuthError(null);
    setIsLoadingAuth(true);
    try {
      await authApi.register(data);
      const currentUser = await authApi.me();
      setUser(currentUser);
      setIsAuthenticated(true);
      return currentUser;
    } finally {
      setIsLoadingAuth(false);
    }
  }, []);

  const logout = useCallback(async (shouldRedirect = false) => {
    // Revoke the session server-side, then wipe every trace of it locally.
    await authApi.logout().catch(() => setToken(null));
    clearCart();
    setUser(null);
    setIsAuthenticated(false);
    setAuthError(null);
    if (shouldRedirect && typeof window !== "undefined") {
      window.location.href = "/";
    }
  }, []);

  const navigateToLogin = useCallback(() => {
    if (typeof window !== "undefined") {
      window.location.href = "/login";
    }
  }, []);

  const refreshUser = useCallback(async () => {
    try {
      const currentUser = await authApi.me();
      setUser(currentUser);
    } catch {
      // Keep the previous user; a 401 is already handled by the global listener.
    }
  }, []);

  return (
    <AuthContext.Provider
      value={{
        user,
        isAuthenticated,
        isLoadingAuth,
        authError,
        login,
        register,
        logout,
        navigateToLogin,
        checkAppState,
        refreshUser,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
};
