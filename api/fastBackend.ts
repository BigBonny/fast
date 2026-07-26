// ─── REAL BACKEND API CLIENT ───────────────────────────────────────────────────
import type {
  ApiError,
  AppNotification,
  Delivery,
  DietaryOption,
  GroupOrder,
  MenuItem,
  Order,
  OrderStatus,
  Restaurant,
  RestaurantStats,
  Review,
  User,
} from "@/lib/types";

const API_URL = process.env.NEXT_PUBLIC_API_URL || "https://backend-lovat-xi-0axv990rct.vercel.app/api";

export const TOKEN_KEY = "fast_token";

const DEFAULT_TIMEOUT_MS = 20000;

export const UNAUTHORIZED_EVENT = "fast:unauthorized";

export function getToken(): string | null {
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

function isApiError(value: unknown): value is ApiError {
  return typeof value === "object" && value !== null && "status" in value && "message" in value;
}

export function getErrorMessage(error: unknown, fallback = "Une erreur est survenue"): string {
  if (isApiError(error)) return error.message;
  if (error instanceof Error) return error.message;
  return fallback;
}

async function apiFetch<T>(path: string, options: RequestInit = {}): Promise<T> {
  const url = `${API_URL}${path}`;
  const headers = buildHeaders(options.body ? { "Content-Type": "application/json" } : {});

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), DEFAULT_TIMEOUT_MS);

  let res: Response;
  try {
    res = await fetch(url, { ...options, headers, signal: options.signal ?? controller.signal });
  } catch (err) {
    clearTimeout(timeout);
    const aborted = err instanceof DOMException && err.name === "AbortError";
    const apiError: ApiError = {
      status: 0,
      message: aborted ? "La requête a expiré. Réessayez." : "Impossible de joindre le serveur.",
    };
    throw apiError;
  }
  clearTimeout(timeout);

  const data = await res.json().catch(() => null);

  if (!res.ok) {
    const message = data?.error || data?.message || `Erreur ${res.status}`;
    if (res.status === 401 && typeof window !== "undefined") {
      setToken(null);
      window.dispatchEvent(new CustomEvent(UNAUTHORIZED_EVENT));
    }
    const apiError: ApiError = { status: res.status, message };
    throw apiError;
  }

  return data as T;
}

function toDietaryOptions(values: unknown): DietaryOption[] {
  if (!Array.isArray(values)) return [];
  return values.map((o) => (typeof o === "string" ? { option: o } : (o as DietaryOption)));
}

function fromDietaryOptions(values: unknown): string[] | undefined {
  if (!Array.isArray(values)) return undefined;
  return values.map((o) => (typeof o === "object" && o !== null ? (o as DietaryOption).option : String(o)));
}

function normalizeRestaurant(r: Restaurant): Restaurant {
  if (!r) return r;
  return {
    ...r,
    dietaryOptions: toDietaryOptions(r.dietaryOptions),
    menuItems: r.menuItems || [],
  };
}

function normalizeMenuItem(m: MenuItem): MenuItem {
  if (!m) return m;
  return {
    ...m,
    dietaryTags: toDietaryOptions(m.dietaryTags),
  };
}

function normalizeOrder(o: Order): Order {
  if (!o) return o;
  return {
    ...o,
    items: (o.items || []).map((item) => ({
      ...item,
      menuItem: item.menuItem || { name: "Article", price: item.price || 0 },
    })),
  };
}

// ─── Auth ─────────────────────────────────────────────────────────────────────

export interface AuthResponse {
  token: string;
  user?: User;
}

export interface RegisterPayload {
  email: string;
  password: string;
  name: string;
  phone?: string;
  role?: string;
}

export const authApi = {
  register: async (data: RegisterPayload): Promise<AuthResponse> => {
    const res = await apiFetch<AuthResponse>("/auth/register", {
      method: "POST",
      body: JSON.stringify(data),
    });
    if (res?.token) setToken(res.token);
    return res;
  },
  login: async (data: { email: string; password: string }): Promise<AuthResponse> => {
    const res = await apiFetch<AuthResponse>("/auth/login", {
      method: "POST",
      body: JSON.stringify(data),
    });
    if (res?.token) setToken(res.token);
    return res;
  },
  me: async (): Promise<User> => {
    return apiFetch<User>("/auth/me");
  },
  updateProfile: async (data: { name?: string; phone?: string }): Promise<User> => {
    return apiFetch<User>("/auth/profile", {
      method: "PATCH",
      body: JSON.stringify(data),
    });
  },
  logout: async (): Promise<null> => {
    await apiFetch<unknown>("/auth/logout", { method: "POST" }).catch(() => {});
    setToken(null);
    return null;
  },
};

// ─── Restaurants ──────────────────────────────────────────────────────────────

export type RestaurantPayload = Partial<Omit<Restaurant, "dietaryOptions">> & {
  dietaryOptions?: (DietaryOption | string)[];
};

export const restaurantApi = {
  list: async (params?: { category?: string; search?: string; dietary?: string }): Promise<Restaurant[]> => {
    const qs = new URLSearchParams();
    if (params?.category && params.category !== "all") qs.set("category", params.category);
    if (params?.search) qs.set("search", params.search);
    if (params?.dietary) qs.set("dietary", params.dietary);
    const list = await apiFetch<Restaurant[]>(`/restaurants?${qs.toString()}`);
    return (list || []).map(normalizeRestaurant);
  },
  get: async (id: string): Promise<Restaurant> => {
    const r = await apiFetch<Restaurant>(`/restaurants/${id}`);
    return normalizeRestaurant(r);
  },
  create: async (data: RestaurantPayload): Promise<Restaurant> => {
    return apiFetch<Restaurant>("/restaurants", {
      method: "POST",
      body: JSON.stringify({ ...data, dietaryOptions: fromDietaryOptions(data.dietaryOptions) ?? [] }),
    });
  },
  update: async (id: string, data: RestaurantPayload): Promise<Restaurant> => {
    return apiFetch<Restaurant>(`/restaurants/${id}`, {
      method: "PATCH",
      body: JSON.stringify({ ...data, dietaryOptions: fromDietaryOptions(data.dietaryOptions) }),
    });
  },
  mine: async (): Promise<Restaurant | null> => {
    return apiFetch<Restaurant | null>("/restaurants/account/mine");
  },
  toggleRush: async (): Promise<Restaurant> => {
    return apiFetch<Restaurant>("/restaurants/toggle-rush", { method: "POST" });
  },
};

// ─── Menu ─────────────────────────────────────────────────────────────────────

export type MenuItemPayload = Partial<Omit<MenuItem, "dietaryTags">> & {
  dietaryTags?: (DietaryOption | string)[];
};

export const menuApi = {
  byRestaurant: async (restaurantId: string): Promise<MenuItem[]> => {
    const items = await apiFetch<MenuItem[]>(`/menu/restaurant/${restaurantId}`);
    return (items || []).map(normalizeMenuItem);
  },
  create: async (restaurantId: string, data: MenuItemPayload): Promise<MenuItem> => {
    return apiFetch<MenuItem>(`/menu/restaurant/${restaurantId}`, {
      method: "POST",
      body: JSON.stringify({ ...data, dietaryTags: fromDietaryOptions(data.dietaryTags) ?? [] }),
    });
  },
  update: async (id: string, data: MenuItemPayload): Promise<MenuItem> => {
    return apiFetch<MenuItem>(`/menu/${id}`, {
      method: "PATCH",
      body: JSON.stringify({ ...data, dietaryTags: fromDietaryOptions(data.dietaryTags) }),
    });
  },
  delete: async (id: string): Promise<void> => {
    return apiFetch<void>(`/menu/${id}`, { method: "DELETE" });
  },
};

// ─── Orders ─────────────────────────────────────────────────────────────────────

export interface CreateOrderPayload {
  restaurantId: string;
  items: {
    menuItemId: string;
    quantity: number;
    selectedOptions?: string[];
    allergyNotes?: string;
  }[];
  userWalkTimeMin?: number;
  allergyNotes?: string;
}

export const orderApi = {
  create: async (data: CreateOrderPayload): Promise<Order> => {
    const order = await apiFetch<Order>("/orders", {
      method: "POST",
      body: JSON.stringify(data),
    });
    return normalizeOrder(order);
  },
  mine: async (status?: OrderStatus): Promise<Order[]> => {
    const qs = status ? `?status=${status}` : "";
    const orders = await apiFetch<Order[]>(`/orders/mine${qs}`);
    return (orders || []).map(normalizeOrder);
  },
  cancel: async (id: string): Promise<Order> => {
    return apiFetch<Order>(`/orders/${id}/cancel`, { method: "POST" });
  },
  restaurantOrders: async (status?: OrderStatus): Promise<Order[]> => {
    const qs = status ? `?status=${status}` : "";
    const orders = await apiFetch<Order[]>(`/orders/restaurant${qs}`);
    return (orders || []).map(normalizeOrder);
  },
  updateStatus: async (id: string, status: OrderStatus): Promise<Order> => {
    const order = await apiFetch<Order>(`/orders/${id}/status`, {
      method: "PATCH",
      body: JSON.stringify({ status }),
    });
    return normalizeOrder(order);
  },
};

// ─── Reviews ────────────────────────────────────────────────────────────────────

export const reviewApi = {
  byRestaurant: async (restaurantId: string): Promise<Review[]> => {
    return apiFetch<Review[]>(`/reviews/restaurant/${restaurantId}`);
  },
  create: async (
    restaurantId: string,
    data: { rating: number; comment?: string; orderId?: string }
  ): Promise<Review> => {
    const qs = data.orderId ? `?orderId=${data.orderId}` : "";
    return apiFetch<Review>(`/reviews/restaurant/${restaurantId}${qs}`, {
      method: "POST",
      body: JSON.stringify({ rating: data.rating, comment: data.comment }),
    });
  },
};

// ─── Notifications ──────────────────────────────────────────────────────────────

export const notificationApi = {
  list: async (): Promise<AppNotification[]> => {
    return apiFetch<AppNotification[]>("/notifications");
  },
  create: async (data: { title: string; body?: string }): Promise<AppNotification> => {
    return apiFetch<AppNotification>("/notifications", {
      method: "POST",
      body: JSON.stringify(data),
    });
  },
  readAll: async (): Promise<void> => {
    return apiFetch<void>("/notifications/read-all", { method: "POST" });
  },
  read: async (id: string): Promise<AppNotification> => {
    return apiFetch<AppNotification>(`/notifications/${id}/read`, { method: "PATCH" });
  },
  delete: async (id: string): Promise<void> => {
    return apiFetch<void>(`/notifications/${id}`, { method: "DELETE" });
  },
  deleteAll: async (): Promise<void> => {
    return apiFetch<void>("/notifications", { method: "DELETE" });
  },
};

// ─── Stats ─────────────────────────────────────────────────────────────────────

export const statsApi = {
  get: async (): Promise<RestaurantStats> => {
    return apiFetch<RestaurantStats>("/stats");
  },
};

// ─── Groups ─────────────────────────────────────────────────────────────────────

export const groupApi = {
  create: async (data: { restaurantId?: string; name?: string } = {}): Promise<GroupOrder> => {
    return apiFetch<GroupOrder>("/groups", {
      method: "POST",
      body: JSON.stringify(data),
    });
  },
  join: async (code: string): Promise<GroupOrder> => {
    return apiFetch<GroupOrder>("/groups/join", {
      method: "POST",
      body: JSON.stringify({ code }),
    });
  },
  mine: async (): Promise<GroupOrder | null> => {
    return apiFetch<GroupOrder | null>("/groups/mine");
  },
  get: async (id: string): Promise<GroupOrder> => {
    return apiFetch<GroupOrder>(`/groups/${id}`);
  },
  leave: async (id: string): Promise<void> => {
    return apiFetch<void>(`/groups/${id}/leave`, { method: "POST" });
  },
};

// ─── Deliveries ─────────────────────────────────────────────────────────────────

export const deliveryApi = {
  available: async (): Promise<Delivery[]> => {
    return apiFetch<Delivery[]>("/deliveries/available");
  },
  active: async (): Promise<Delivery[]> => {
    return apiFetch<Delivery[]>("/deliveries/active");
  },
  accept: async (id: string): Promise<Delivery> => {
    return apiFetch<Delivery>(`/deliveries/${id}/accept`, { method: "POST" });
  },
  updateStatus: async (id: string, status: string): Promise<Delivery> => {
    return apiFetch<Delivery>(`/deliveries/${id}/status`, {
      method: "PATCH",
      body: JSON.stringify({ status }),
    });
  },
  generate: async (data: { orderId: string }): Promise<Delivery> => {
    return apiFetch<Delivery>("/deliveries/generate", {
      method: "POST",
      body: JSON.stringify(data),
    });
  },
};

// ─── Health ─────────────────────────────────────────────────────────────────────

export const healthApi = {
  check: async (): Promise<{ status: string }> => {
    return apiFetch<{ status: string }>("/health");
  },
};

export default authApi;
