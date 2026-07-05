// ─── REAL BACKEND API CLIENT ───────────────────────────────────────────────────
const API_URL = process.env.NEXT_PUBLIC_API_URL || "https://backend-lovat-xi-0axv990rct.vercel.app/api";

const TOKEN_KEY = "fast_token";

function getToken(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string | null) {
  if (typeof window === "undefined") return;
  if (token) localStorage.setItem(TOKEN_KEY, token);
  else localStorage.removeItem(TOKEN_KEY);
}

function buildHeaders(extra: Record<string, string> = {}): Record<string, string> {
  const headers: Record<string, string> = {
    Accept: "application/json",
    ...extra,
  };
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;
  return headers;
}

async function apiFetch(path: string, options: RequestInit = {}): Promise<any> {
  const url = `${API_URL}${path}`;
  const headers = buildHeaders(options.body ? { "Content-Type": "application/json" } : {});

  const res = await fetch(url, {
    ...options,
    headers,
  });

  const data = await res.json().catch(() => null);

  if (!res.ok) {
    const message = data?.error || data?.message || `Erreur ${res.status}`;
    throw { status: res.status, message };
  }

  return data;
}

function normalizeRestaurant(r: any): any {
  if (!r) return r;
  return {
    ...r,
    dietaryOptions: (r.dietaryOptions || []).map((o: any) => (typeof o === "string" ? { option: o } : o)),
    menuItems: r.menuItems || [],
  };
}

function normalizeMenuItem(m: any): any {
  if (!m) return m;
  return {
    ...m,
    dietaryTags: (m.dietaryTags || []).map((t: any) => (typeof t === "string" ? { option: t } : t)),
  };
}

function normalizeOrder(o: any): any {
  if (!o) return o;
  return {
    ...o,
    items: (o.items || []).map((item: any) => ({
      ...item,
      menuItem: item.menuItem || { name: item.name || "Article", price: item.price || 0 },
    })),
  };
}

// ─── Auth ─────────────────────────────────────────────────────────────────────

export const authApi = {
  register: async (data: { email: string; password: string; name: string; phone?: string; role?: string }) => {
    const res = await apiFetch("/auth/register", {
      method: "POST",
      body: JSON.stringify(data),
    });
    if (res.token) setToken(res.token);
    return res;
  },
  login: async (data: { email: string; password: string }) => {
    const res = await apiFetch("/auth/login", {
      method: "POST",
      body: JSON.stringify(data),
    });
    if (res.token) setToken(res.token);
    return res;
  },
  me: async () => {
    return apiFetch("/auth/me");
  },
  updateProfile: async (data: { name?: string; phone?: string }) => {
    return apiFetch("/auth/profile", {
      method: "PATCH",
      body: JSON.stringify(data),
    });
  },
  logout: async () => {
    await apiFetch("/auth/logout", { method: "POST" }).catch(() => {});
    setToken(null);
    return null;
  },
};

// ─── Restaurants ──────────────────────────────────────────────────────────────

export const restaurantApi = {
  list: async (params?: { category?: string; search?: string; dietary?: string }) => {
    const qs = new URLSearchParams();
    if (params?.category && params.category !== "all") qs.set("category", params.category);
    if (params?.search) qs.set("search", params.search);
    if (params?.dietary) qs.set("dietary", params.dietary);
    const list = await apiFetch(`/restaurants?${qs.toString()}`);
    return (list || []).map(normalizeRestaurant);
  },
  get: async (id: string) => {
    const r = await apiFetch(`/restaurants/${id}`);
    return normalizeRestaurant(r);
  },
  create: async (data: any) => {
    const payload = {
      ...data,
      dietaryOptions: (data.dietaryOptions || []).map((o: any) => (typeof o === "object" ? o.option : o)),
    };
    return apiFetch("/restaurants", {
      method: "POST",
      body: JSON.stringify(payload),
    });
  },
  update: async (id: string, data: any) => {
    const payload = {
      ...data,
      dietaryOptions: data.dietaryOptions
        ? data.dietaryOptions.map((o: any) => (typeof o === "object" ? o.option : o))
        : undefined,
    };
    return apiFetch(`/restaurants/${id}`, {
      method: "PATCH",
      body: JSON.stringify(payload),
    });
  },
  mine: async () => {
    return apiFetch("/restaurants/account/mine");
  },
  toggleRush: async () => {
    return apiFetch("/restaurants/toggle-rush", { method: "POST" });
  },
};

// ─── Menu ─────────────────────────────────────────────────────────────────────

export const menuApi = {
  byRestaurant: async (restaurantId: string) => {
    const items = await apiFetch(`/menu/restaurant/${restaurantId}`);
    return (items || []).map(normalizeMenuItem);
  },
  create: async (restaurantId: string, data: any) => {
    const payload = {
      ...data,
      dietaryTags: (data.dietaryTags || []).map((t: any) => (typeof t === "object" ? t.option : t)),
    };
    return apiFetch(`/menu/restaurant/${restaurantId}`, {
      method: "POST",
      body: JSON.stringify(payload),
    });
  },
  update: async (id: string, data: any) => {
    const payload = {
      ...data,
      dietaryTags: data.dietaryTags
        ? data.dietaryTags.map((t: any) => (typeof t === "object" ? t.option : t))
        : undefined,
    };
    return apiFetch(`/menu/${id}`, {
      method: "PATCH",
      body: JSON.stringify(payload),
    });
  },
  delete: async (id: string) => {
    return apiFetch(`/menu/${id}`, { method: "DELETE" });
  },
};

// ─── Orders ─────────────────────────────────────────────────────────────────────

export const orderApi = {
  create: async (data: any) => {
    const order = await apiFetch("/orders", {
      method: "POST",
      body: JSON.stringify(data),
    });
    return normalizeOrder(order);
  },
  mine: async (status?: string) => {
    const qs = status ? `?status=${status}` : "";
    const orders = await apiFetch(`/orders/mine${qs}`);
    return (orders || []).map(normalizeOrder);
  },
  cancel: async (id: string) => {
    return apiFetch(`/orders/${id}/cancel`, { method: "POST" });
  },
  restaurantOrders: async (status?: string) => {
    const qs = status ? `?status=${status}` : "";
    const orders = await apiFetch(`/orders/restaurant${qs}`);
    return (orders || []).map(normalizeOrder);
  },
  updateStatus: async (id: string, status: string) => {
    const order = await apiFetch(`/orders/${id}/status`, {
      method: "PATCH",
      body: JSON.stringify({ status }),
    });
    return normalizeOrder(order);
  },
};

// ─── Reviews ────────────────────────────────────────────────────────────────────

export const reviewApi = {
  byRestaurant: async (restaurantId: string) => {
    return apiFetch(`/reviews/restaurant/${restaurantId}`);
  },
  create: async (restaurantId: string, data: any) => {
    const qs = data.orderId ? `?orderId=${data.orderId}` : "";
    return apiFetch(`/reviews/restaurant/${restaurantId}${qs}`, {
      method: "POST",
      body: JSON.stringify({ rating: data.rating, comment: data.comment }),
    });
  },
};

// ─── Notifications ──────────────────────────────────────────────────────────────

export const notificationApi = {
  list: async () => {
    return apiFetch("/notifications");
  },
  create: async (data: any) => {
    return apiFetch("/notifications", {
      method: "POST",
      body: JSON.stringify(data),
    });
  },
  readAll: async () => {
    return apiFetch("/notifications/read-all", { method: "POST" });
  },
  read: async (id: string) => {
    return apiFetch(`/notifications/${id}/read`, { method: "PATCH" });
  },
  delete: async (id: string) => {
    return apiFetch(`/notifications/${id}`, { method: "DELETE" });
  },
  deleteAll: async () => {
    return apiFetch("/notifications", { method: "DELETE" });
  },
};

// ─── Stats ─────────────────────────────────────────────────────────────────────

export const statsApi = {
  get: async () => {
    return apiFetch("/stats");
  },
};

// ─── Groups ─────────────────────────────────────────────────────────────────────

export const groupApi = {
  create: async (data: any) => {
    return apiFetch("/groups", {
      method: "POST",
      body: JSON.stringify(data),
    });
  },
  join: async (code: string) => {
    return apiFetch("/groups/join", {
      method: "POST",
      body: JSON.stringify({ code }),
    });
  },
  mine: async () => {
    return apiFetch("/groups/mine");
  },
  get: async (id: string) => {
    return apiFetch(`/groups/${id}`);
  },
  leave: async (id: string) => {
    return apiFetch(`/groups/${id}/leave`, { method: "POST" });
  },
};

// ─── Deliveries ─────────────────────────────────────────────────────────────────

export const deliveryApi = {
  available: async () => {
    return apiFetch("/deliveries/available");
  },
  active: async () => {
    return apiFetch("/deliveries/active");
  },
  accept: async (id: string) => {
    return apiFetch(`/deliveries/${id}/accept`, { method: "POST" });
  },
  updateStatus: async (id: string, status: string) => {
    return apiFetch(`/deliveries/${id}/status`, {
      method: "PATCH",
      body: JSON.stringify({ status }),
    });
  },
  generate: async (data: any) => {
    return apiFetch("/deliveries/generate", {
      method: "POST",
      body: JSON.stringify(data),
    });
  },
};

// ─── Health ─────────────────────────────────────────────────────────────────────

export const healthApi = {
  check: async () => {
    return apiFetch("/health");
  },
};

export default authApi;
