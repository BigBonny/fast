"use client";

import React, { createContext, useState, useContext, useEffect, ReactNode } from "react";
import { authApi } from "@/api/fastBackend";

interface AuthError {
  type: string;
  message: string;
}

interface AuthContextType {
  user: any;
  isAuthenticated: boolean;
  isLoadingAuth: boolean;
  isLoadingPublicSettings: boolean;
  authError: AuthError | null;
  appPublicSettings: any;
  login: (email: string, password: string) => Promise<any>;
  register: (data: { email: string; password: string; name: string; phone?: string; role?: string }) => Promise<any>;
  logout: (shouldRedirect?: boolean) => void;
  navigateToLogin: () => void;
  checkAppState: () => Promise<void>;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider = ({ children }: { children: ReactNode }) => {
  const [user, setUser] = useState<any>(null);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoadingAuth, setIsLoadingAuth] = useState(true);
  const [isLoadingPublicSettings, setIsLoadingPublicSettings] = useState(false);
  const [authError, setAuthError] = useState<AuthError | null>(null);

  useEffect(() => {
    checkAppState();
  }, []);

  const checkAppState = async () => {
    try {
      setAuthError(null);
      const token = typeof window !== "undefined" ? localStorage.getItem("fast_token") : null;
      if (!token) {
        setIsAuthenticated(false);
        setIsLoadingAuth(false);
        return;
      }
      await checkUserAuth();
    } catch (error: any) {
      console.error("Unexpected error:", error);
      setAuthError({
        type: "unknown",
        message: error.message || "An unexpected error occurred",
      });
      setIsLoadingAuth(false);
    }
  };

  const checkUserAuth = async () => {
    try {
      setIsLoadingAuth(true);
      const currentUser = await authApi.me();
      setUser(currentUser);
      setIsAuthenticated(true);
      setIsLoadingAuth(false);
    } catch (error: any) {
      console.error("User auth check failed:", error);
      setIsLoadingAuth(false);
      setIsAuthenticated(false);
      if (error?.status === 401 || error?.status === 403) {
        setAuthError({
          type: "auth_required",
          message: "Authentication required",
        });
      }
    }
  };

  const login = async (email: string, password: string) => {
    setAuthError(null);
    setIsLoadingAuth(true);
    try {
      const res = await authApi.login({ email, password });
      if (res.token && typeof window !== "undefined") {
        localStorage.setItem("fast_token", res.token);
      }
      const currentUser = await authApi.me();
      setUser(currentUser);
      setIsAuthenticated(true);
      setIsLoadingAuth(false);
      return currentUser;
    } catch (error: any) {
      setIsLoadingAuth(false);
      throw error;
    }
  };

  const register = async (data: { email: string; password: string; name: string; phone?: string; role?: string }) => {
    setAuthError(null);
    setIsLoadingAuth(true);
    try {
      const res = await authApi.register(data);
      if (res.token && typeof window !== "undefined") {
        localStorage.setItem("fast_token", res.token);
      }
      const currentUser = await authApi.me();
      setUser(currentUser);
      setIsAuthenticated(true);
      setIsLoadingAuth(false);
      return currentUser;
    } catch (error: any) {
      setIsLoadingAuth(false);
      throw error;
    }
  };

  const logout = () => {
    setUser(null);
    setIsAuthenticated(false);
    if (typeof window !== "undefined") {
      localStorage.removeItem("fast_token");
    }
  };

  const navigateToLogin = () => {
    if (typeof window !== "undefined") {
      window.location.href = "/login";
    }
  };

  const refreshUser = async () => {
    try {
      const currentUser = await authApi.me();
      setUser(currentUser);
    } catch (error: any) {
      console.error("refreshUser failed:", error);
    }
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        isAuthenticated,
        isLoadingAuth,
        isLoadingPublicSettings,
        authError,
        appPublicSettings: null,
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
