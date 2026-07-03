const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:3000";

function getToken() {
  if (typeof window === "undefined") return null;
  return localStorage.getItem("fast_token");
}

async function apiFetch(path: string, options: RequestInit = {}) {
  const url = `${API_BASE_URL}${path}`;
  const token = getToken();
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(options.headers as Record<string, string>),
  };
  if (token) {
    headers["Authorization"] = `Bearer ${token}`;
  }

  const res = await fetch(url, { ...options, headers });
  if (!res.ok) {
    const text = await res.text();
    let error: any = { status: res.status, message: text };
    try {
      error = JSON.parse(text);
    } catch {}
    throw error;
  }
  if (res.status === 204) return null;
  return res.json();
}

// Auth
export const authApi = {
  register: (data: { email: string; password: string; name: string; phone?: string; role?: string }) =>
    apiFetch("/api/auth/register", { method: "POST", body: JSON.stringify(data) }),
  login: (data: { email: string; password: string }) =>
    apiFetch("/api/auth/login", { method: "POST", body: JSON.stringify(data) }),
  me: () => apiFetch("/api/auth/me"),
  updateProfile: (data: { name?: string; phone?: string }) =>
    apiFetch("/api/auth/profile", { method: "PATCH", body: JSON.stringify(data) }),
  logout: () => apiFetch("/api/auth/logout", { method: "POST" }),
};

// Restaurants
export const restaurantApi = {
  list: (params?: { category?: string; search?: string; dietary?: string }) => {
    const query = new URLSearchParams(params as Record<string, string>).toString();
    return apiFetch(`/api/restaurants${query ? `?${query}` : ""}`);
  },
  get: (id: string) => apiFetch(`/api/restaurants/${id}`),
  create: (data: any) => apiFetch("/api/restaurants", { method: "POST", body: JSON.stringify(data) }),
  update: (id: string, data: any) => apiFetch(`/api/restaurants/${id}`, { method: "PATCH", body: JSON.stringify(data) }),
  mine: () => apiFetch("/api/restaurants/account/mine"),
  toggleRush: () => apiFetch("/api/restaurants/toggle-rush", { method: "POST" }),
};

// Menu
export const menuApi = {
  byRestaurant: (restaurantId: string) => apiFetch(`/api/menu/restaurant/${restaurantId}`),
  create: (restaurantId: string, data: any) =>
    apiFetch(`/api/menu/restaurant/${restaurantId}`, { method: "POST", body: JSON.stringify(data) }),
  update: (id: string, data: any) => apiFetch(`/api/menu/${id}`, { method: "PATCH", body: JSON.stringify(data) }),
  delete: (id: string) => apiFetch(`/api/menu/${id}`, { method: "DELETE" }),
};

// Orders
export const orderApi = {
  create: (data: any) => apiFetch("/api/orders", { method: "POST", body: JSON.stringify(data) }),
  mine: (status?: string) => {
    const query = status ? `?status=${status}` : "";
    return apiFetch(`/api/orders/mine${query}`);
  },
  cancel: (id: string) => apiFetch(`/api/orders/${id}/cancel`, { method: "POST" }),
  restaurantOrders: (status?: string) => {
    const query = status ? `?status=${status}` : "";
    return apiFetch(`/api/orders/restaurant${query}`);
  },
  updateStatus: (id: string, status: string) =>
    apiFetch(`/api/orders/${id}/status`, { method: "PATCH", body: JSON.stringify({ status }) }),
};

// Reviews
export const reviewApi = {
  byRestaurant: (restaurantId: string) => apiFetch(`/api/reviews/restaurant/${restaurantId}`),
  create: (restaurantId: string, data: any) =>
    apiFetch(`/api/reviews/restaurant/${restaurantId}`, { method: "POST", body: JSON.stringify(data) }),
};

// Notifications
export const notificationApi = {
  list: () => apiFetch("/api/notifications"),
  create: (data: any) => apiFetch("/api/notifications", { method: "POST", body: JSON.stringify(data) }),
  readAll: () => apiFetch("/api/notifications/read-all", { method: "POST" }),
  read: (id: string) => apiFetch(`/api/notifications/${id}/read`, { method: "PATCH" }),
  delete: (id: string) => apiFetch(`/api/notifications/${id}`, { method: "DELETE" }),
  deleteAll: () => apiFetch("/api/notifications", { method: "DELETE" }),
};

// Stats
export const statsApi = {
  get: () => apiFetch("/api/stats"),
};

// Groups
export const groupApi = {
  create: (data: any) => apiFetch("/api/groups", { method: "POST", body: JSON.stringify(data) }),
  join: (code: string) => apiFetch("/api/groups/join", { method: "POST", body: JSON.stringify({ code }) }),
  mine: () => apiFetch("/api/groups/mine"),
  get: (id: string) => apiFetch(`/api/groups/${id}`),
  leave: (id: string) => apiFetch(`/api/groups/${id}/leave`, { method: "POST" }),
};

// Deliveries
export const deliveryApi = {
  available: () => apiFetch("/api/deliveries/available"),
  active: () => apiFetch("/api/deliveries/active"),
  accept: (id: string) => apiFetch(`/api/deliveries/${id}/accept`, { method: "POST" }),
  updateStatus: (id: string, status: string) =>
    apiFetch(`/api/deliveries/${id}/status`, { method: "PATCH", body: JSON.stringify({ status }) }),
  generate: () => apiFetch("/api/deliveries/generate", { method: "POST" }),
};

// Health
export const healthApi = {
  check: () => apiFetch("/api/health"),
};

export default apiFetch;
