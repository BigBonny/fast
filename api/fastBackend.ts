// ─── MOCK API — no backend required ───────────────────────────────────────────
// All data is persisted in localStorage so the demo is fully functional.

function delay(ms = 120) {
  return new Promise((r) => setTimeout(r, ms));
}

function uid() {
  return Math.random().toString(36).slice(2, 10);
}

function ls<T>(key: string, def: T): T {
  if (typeof window === "undefined") return def;
  try {
    const v = localStorage.getItem(key);
    return v ? JSON.parse(v) : def;
  } catch {
    return def;
  }
}

function lsSet(key: string, value: any) {
  if (typeof window !== "undefined") localStorage.setItem(key, JSON.stringify(value));
}

// ─── Seed data ─────────────────────────────────────────────────────────────────

const SEED_RESTAURANTS = [
  { id: "r1", name: "Burger Palace", description: "Les meilleurs burgers de la ville", cuisineType: "burger", category: "fast-food", address: "12 Rue de la Paix", city: "Paris", rating: 4.8, reviewsCount: 124, normalPrepTime: 12, rushPrepTime: 20, pickupPrepTime: 10, isRushMode: false, image: "", dietaryOptions: [] },
  { id: "r2", name: "Pizza Roma", description: "Authentique pizza napolitaine", cuisineType: "pizza", category: "italien", address: "34 Avenue Victor Hugo", city: "Paris", rating: 4.6, reviewsCount: 89, normalPrepTime: 15, rushPrepTime: 25, pickupPrepTime: 12, isRushMode: false, image: "", dietaryOptions: [{ option: "VEGETARIAN" }] },
  { id: "r3", name: "Sushi Zen", description: "Sushis frais préparés à la commande", cuisineType: "sushi", category: "japonais", address: "8 Rue du Faubourg", city: "Paris", rating: 4.9, reviewsCount: 203, normalPrepTime: 18, rushPrepTime: 28, pickupPrepTime: 15, isRushMode: true, image: "", dietaryOptions: [{ option: "GLUTEN_FREE" }] },
  { id: "r4", name: "Tacos House", description: "Tacos généreux et savoureux", cuisineType: "tacos", category: "mexicain", address: "56 Rue Nationale", city: "Lyon", rating: 4.5, reviewsCount: 67, normalPrepTime: 10, rushPrepTime: 18, pickupPrepTime: 8, isRushMode: false, image: "", dietaryOptions: [] },
  { id: "r5", name: "Green Bowl", description: "Cuisine vegan et végétarienne", cuisineType: "vegan", category: "healthy", address: "22 Boulevard Haussmann", city: "Paris", rating: 4.7, reviewsCount: 145, normalPrepTime: 14, rushPrepTime: 22, pickupPrepTime: 11, isRushMode: false, image: "", dietaryOptions: [{ option: "VEGAN" }, { option: "GLUTEN_FREE" }] },
];

const SEED_MENUS: Record<string, any[]> = {
  r1: [
    { id: "m1", restaurantId: "r1", name: "Classic Burger", description: "Bœuf, cheddar, salade, tomate", price: 9.90, category: "Burgers", image: "", isAvailable: true, dietaryTags: [] },
    { id: "m2", restaurantId: "r1", name: "Double Smash", description: "Double steak haché, sauce spéciale", price: 12.90, category: "Burgers", image: "", isAvailable: true, dietaryTags: [] },
    { id: "m3", restaurantId: "r1", name: "Chicken Burger", description: "Poulet croustillant, mayo", price: 10.50, category: "Burgers", image: "", isAvailable: true, dietaryTags: [] },
    { id: "m4", restaurantId: "r1", name: "Frites maison", description: "Pommes de terre fraîches", price: 3.50, category: "Accompagnements", image: "", isAvailable: true, dietaryTags: [{ option: "VEGAN" }] },
    { id: "m5", restaurantId: "r1", name: "Coca-Cola", description: "33cl", price: 2.50, category: "Boissons", image: "", isAvailable: true, dietaryTags: [] },
  ],
  r2: [
    { id: "m6", restaurantId: "r2", name: "Margherita", description: "Tomate, mozzarella, basilic", price: 11.00, category: "Pizzas", image: "", isAvailable: true, dietaryTags: [{ option: "VEGETARIAN" }] },
    { id: "m7", restaurantId: "r2", name: "4 Fromages", description: "Mozzarella, gorgonzola, parmesan, chèvre", price: 13.50, category: "Pizzas", image: "", isAvailable: true, dietaryTags: [{ option: "VEGETARIAN" }] },
    { id: "m8", restaurantId: "r2", name: "Pepperoni", description: "Tomate, mozzarella, pepperoni", price: 12.50, category: "Pizzas", image: "", isAvailable: true, dietaryTags: [] },
    { id: "m9", restaurantId: "r2", name: "Tiramisu", description: "Fait maison", price: 5.50, category: "Desserts", image: "", isAvailable: true, dietaryTags: [{ option: "VEGETARIAN" }] },
  ],
  r3: [
    { id: "m10", restaurantId: "r3", name: "California Roll x8", description: "Avocat, surimi, concombre", price: 9.50, category: "Makis", image: "", isAvailable: true, dietaryTags: [] },
    { id: "m11", restaurantId: "r3", name: "Saumon Nigiri x4", description: "Saumon frais sur riz vinaigré", price: 8.00, category: "Nigiris", image: "", isAvailable: true, dietaryTags: [{ option: "GLUTEN_FREE" }] },
    { id: "m12", restaurantId: "r3", name: "Plateau Zen 30p", description: "Assortiment makis, nigiris, sashimis", price: 22.90, category: "Plateaux", image: "", isAvailable: true, dietaryTags: [] },
    { id: "m13", restaurantId: "r3", name: "Edamame", description: "Fèves de soja salées", price: 4.00, category: "Entrées", image: "", isAvailable: true, dietaryTags: [{ option: "VEGAN" }, { option: "GLUTEN_FREE" }] },
  ],
  r4: [
    { id: "m14", restaurantId: "r4", name: "Tacos Poulet", description: "Poulet grillé, fromage, sauce fromagère", price: 7.50, category: "Tacos", image: "", isAvailable: true, dietaryTags: [] },
    { id: "m15", restaurantId: "r4", name: "Tacos Mixte", description: "Poulet + viande hachée, sauce blanche", price: 8.50, category: "Tacos", image: "", isAvailable: true, dietaryTags: [] },
    { id: "m16", restaurantId: "r4", name: "Burrito Végé", description: "Haricots, maïs, guacamole", price: 8.00, category: "Burritos", image: "", isAvailable: true, dietaryTags: [{ option: "VEGETARIAN" }] },
  ],
  r5: [
    { id: "m17", restaurantId: "r5", name: "Buddha Bowl", description: "Quinoa, légumes rôtis, tahini", price: 12.00, category: "Bols", image: "", isAvailable: true, dietaryTags: [{ option: "VEGAN" }, { option: "GLUTEN_FREE" }] },
    { id: "m18", restaurantId: "r5", name: "Smoothie Detox", description: "Épinards, pomme, gingembre", price: 5.50, category: "Boissons", image: "", isAvailable: true, dietaryTags: [{ option: "VEGAN" }] },
    { id: "m19", restaurantId: "r5", name: "Wrap Végétarien", description: "Avocat, houmous, légumes croquants", price: 9.50, category: "Wraps", image: "", isAvailable: true, dietaryTags: [{ option: "VEGETARIAN" }] },
  ],
};

function getRestaurants() {
  const stored = ls<any[]>("mock_restaurants", []);
  const base = stored.length === 0 ? SEED_RESTAURANTS : stored;
  // always ensure demo restaurant exists
  if (!base.find((r: any) => r.id === DEMO_RESTAURANT.id)) {
    return [DEMO_RESTAURANT, ...base];
  }
  return base;
}

function getMenuItems() {
  const stored = ls<Record<string, any[]>>("mock_menus", {});
  const isEmpty = Object.keys(stored).length === 0;
  const base = isEmpty ? { ...SEED_MENUS } : { ...stored };
  // always ensure demo menu exists
  if (!base["demo_r"] || base["demo_r"].length === 0) {
    base["demo_r"] = DEMO_MENU;
  }
  return base;
}

const DEMO_USERS = [
  { id: "demo_client", email: "client@fast.demo", password: "Demo1234", name: "Alex Dupont", phone: "0612345678", role: "CLIENT", points: 85, restaurant: null },
  { id: "demo_resto", email: "resto@fast.demo", password: "Demo1234", name: "Chef Marco", phone: "0698765432", role: "RESTAURANT", points: 0, restaurant: null },
];

const DEMO_RESTAURANT = {
  id: "demo_r",
  ownerId: "demo_resto",
  name: "La Belle Assiette",
  description: "Cuisine française raffinée, faite maison avec des produits frais.",
  cuisineType: "français",
  category: "gastronomique",
  address: "15 Rue des Gourmets",
  city: "Paris",
  rating: 4.7,
  reviewsCount: 52,
  normalPrepTime: 15,
  rushPrepTime: 25,
  pickupPrepTime: 12,
  isRushMode: false,
  image: "",
  dietaryOptions: [{ option: "VEGETARIAN" }],
};

const DEMO_MENU: any[] = [
  { id: "dm1", restaurantId: "demo_r", name: "Soupe à l'oignon", description: "Gratinée, pain maison", price: 7.50, category: "Entrées", image: "", isAvailable: true, dietaryTags: [{ option: "VEGETARIAN" }] },
  { id: "dm2", restaurantId: "demo_r", name: "Steak Frites", description: "Entrecôte, frites maison, sauce au poivre", price: 16.90, category: "Plats", image: "", isAvailable: true, dietaryTags: [] },
  { id: "dm3", restaurantId: "demo_r", name: "Poulet rôti", description: "Demi-poulet, jus de cuisson, pommes sautées", price: 14.50, category: "Plats", image: "", isAvailable: true, dietaryTags: [] },
  { id: "dm4", restaurantId: "demo_r", name: "Crème brûlée", description: "Vanille de Madagascar", price: 6.00, category: "Desserts", image: "", isAvailable: true, dietaryTags: [{ option: "VEGETARIAN" }] },
  { id: "dm5", restaurantId: "demo_r", name: "Eau minérale", description: "50cl", price: 2.50, category: "Boissons", image: "", isAvailable: true, dietaryTags: [{ option: "VEGAN" }] },
];

function getUsers(): any[] {
  const stored = ls<any[]>("mock_users", []);
  // always ensure demo accounts exist
  const merged = [...DEMO_USERS];
  stored.forEach((u) => { if (!DEMO_USERS.find((d) => d.id === u.id)) merged.push(u); });
  return merged;
}
function saveUsers(u: any[]) {
  // never overwrite demo users, only save non-demo ones
  const custom = u.filter((x) => !DEMO_USERS.find((d) => d.id === x.id));
  lsSet("mock_users", custom);
}
function getOrders(): any[] { return ls("mock_orders", []); }
function saveOrders(o: any[]) { lsSet("mock_orders", o); }
function currentUser(): any | null { return ls("mock_current_user", null); }
function saveCurrentUser(u: any) { lsSet("mock_current_user", u); }

// ─── Auth ──────────────────────────────────────────────────────────────────────

export const authApi = {
  register: async (data: { email: string; password: string; name: string; phone?: string; role?: string }) => {
    await delay();
    const users = getUsers();
    if (users.find((u) => u.email === data.email)) throw { status: 409, message: "Cet email est déjà utilisé." };
    const user = { id: uid(), email: data.email, name: data.name, phone: data.phone || "", role: data.role || "CLIENT", points: 0, restaurant: null };
    users.push({ ...user, password: data.password });
    saveUsers(users);
    saveCurrentUser(user);
    lsSet("fast_token", "mock_" + user.id);
    return { token: "mock_" + user.id, user };
  },
  login: async (data: { email: string; password: string }) => {
    await delay();
    const users = getUsers();
    const found = users.find((u) => u.email === data.email && u.password === data.password);
    if (!found) throw { status: 401, message: "Email ou mot de passe incorrect." };
    const user = { id: found.id, email: found.email, name: found.name, phone: found.phone, role: found.role, points: found.points || 0, restaurant: found.restaurant || null };
    saveCurrentUser(user);
    lsSet("fast_token", "mock_" + user.id);
    return { token: "mock_" + user.id, user };
  },
  me: async () => {
    await delay(50);
    const u = currentUser();
    if (!u) throw { status: 401, message: "Non authentifié" };
    // refresh restaurant data if RESTAURANT role
    if (u.role === "RESTAURANT") {
      const rests = getRestaurants();
      const mine = rests.find((r: any) => r.ownerId === u.id);
      u.restaurant = mine || null;
    }
    return u;
  },
  updateProfile: async (data: { name?: string; phone?: string }) => {
    await delay();
    const u = currentUser();
    if (!u) throw { status: 401, message: "Non authentifié" };
    if (data.name) u.name = data.name;
    if (data.phone !== undefined) u.phone = data.phone;
    saveCurrentUser(u);
    // also update in users array
    const users = getUsers();
    const idx = users.findIndex((x) => x.id === u.id);
    if (idx >= 0) { users[idx] = { ...users[idx], ...data }; saveUsers(users); }
    return u;
  },
  logout: async () => { await delay(50); return null; },
};

// ─── Restaurants ───────────────────────────────────────────────────────────────

export const restaurantApi = {
  list: async (params?: { category?: string; search?: string; dietary?: string }) => {
    await delay();
    let rests = getRestaurants();
    if (params?.search) { const q = params.search.toLowerCase(); rests = rests.filter((r: any) => r.name?.toLowerCase().includes(q) || r.cuisineType?.toLowerCase().includes(q)); }
    if (params?.category) { rests = rests.filter((r: any) => r.cuisineType?.toLowerCase() === params.category?.toLowerCase() || r.category?.toLowerCase() === params.category?.toLowerCase()); }
    return rests;
  },
  get: async (id: string) => {
    await delay();
    const r = getRestaurants().find((x: any) => x.id === id);
    if (!r) throw { status: 404, message: "Restaurant introuvable" };
    const menus = getMenuItems();
    return { ...r, menuItems: menus[id] || [] };
  },
  create: async (data: any) => {
    await delay();
    const u = currentUser();
    if (!u) throw { status: 401, message: "Non authentifié" };
    const rests = getRestaurants();
    if (rests.find((r: any) => r.ownerId === u.id)) throw { status: 409, message: "Vous avez déjà un restaurant." };
    const r = { id: uid(), ownerId: u.id, rating: 0, reviewsCount: 0, isRushMode: false, ...data };
    rests.push(r);
    lsSet("mock_restaurants", rests);
    u.restaurant = r;
    saveCurrentUser(u);
    return r;
  },
  update: async (id: string, data: any) => {
    await delay();
    const rests = getRestaurants();
    const idx = rests.findIndex((r: any) => r.id === id);
    if (idx < 0) throw { status: 404, message: "Restaurant introuvable" };
    rests[idx] = { ...rests[idx], ...data };
    lsSet("mock_restaurants", rests);
    const u = currentUser();
    if (u) { u.restaurant = rests[idx]; saveCurrentUser(u); }
    return rests[idx];
  },
  mine: async () => {
    await delay();
    const u = currentUser();
    if (!u) throw { status: 401, message: "Non authentifié" };
    const rests = getRestaurants();
    const mine = rests.find((r: any) => r.ownerId === u.id);
    if (!mine) throw { status: 404, message: "Aucun restaurant trouvé" };
    return mine;
  },
  toggleRush: async () => {
    await delay();
    const u = currentUser();
    if (!u) throw { status: 401, message: "Non authentifié" };
    const rests = getRestaurants();
    const idx = rests.findIndex((r: any) => r.ownerId === u.id);
    if (idx < 0) throw { status: 404, message: "Aucun restaurant trouvé" };
    rests[idx].isRushMode = !rests[idx].isRushMode;
    lsSet("mock_restaurants", rests);
    return rests[idx];
  },
};

// ─── Menu ──────────────────────────────────────────────────────────────────────

export const menuApi = {
  byRestaurant: async (restaurantId: string) => {
    await delay();
    const menus = getMenuItems();
    return menus[restaurantId] || [];
  },
  create: async (restaurantId: string, data: any) => {
    await delay();
    const menus = getMenuItems();
    const item = { id: uid(), restaurantId, isAvailable: true, dietaryTags: (data.dietaryTags || []).map((t: string) => ({ option: t })), ...data };
    menus[restaurantId] = [...(menus[restaurantId] || []), item];
    lsSet("mock_menus", menus);
    return item;
  },
  update: async (id: string, data: any) => {
    await delay();
    const menus = getMenuItems();
    for (const rid of Object.keys(menus)) {
      const idx = menus[rid].findIndex((i: any) => i.id === id);
      if (idx >= 0) {
        const updated = { ...menus[rid][idx], ...data };
        if (data.dietaryTags) updated.dietaryTags = data.dietaryTags.map((t: string) => typeof t === "string" ? { option: t } : t);
        menus[rid][idx] = updated;
        lsSet("mock_menus", menus);
        return updated;
      }
    }
    throw { status: 404, message: "Article introuvable" };
  },
  delete: async (id: string) => {
    await delay();
    const menus = getMenuItems();
    for (const rid of Object.keys(menus)) {
      const idx = menus[rid].findIndex((i: any) => i.id === id);
      if (idx >= 0) { menus[rid].splice(idx, 1); lsSet("mock_menus", menus); return null; }
    }
    throw { status: 404, message: "Article introuvable" };
  },
};

// ─── Orders ────────────────────────────────────────────────────────────────────

export const orderApi = {
  create: async (data: any) => {
    await delay();
    const u = currentUser();
    const order = {
      id: uid(), userId: u?.id, user: u ? { name: u.name } : null, status: "PLACED",
      items: data.items || [], total: data.total || 0, subtotal: data.subtotal || 0,
      serviceFee: data.serviceFee || 1.5, allergyNotes: data.allergyNotes || "",
      restaurantId: data.restaurantId, createdAt: new Date().toISOString(),
    };
    const orders = getOrders();
    orders.unshift(order);
    saveOrders(orders);
    return order;
  },
  mine: async (status?: string) => {
    await delay();
    const u = currentUser();
    let orders = getOrders().filter((o: any) => o.userId === u?.id);
    if (status) orders = orders.filter((o: any) => o.status === status);
    return orders;
  },
  cancel: async (id: string) => {
    await delay();
    const orders = getOrders();
    const idx = orders.findIndex((o: any) => o.id === id);
    if (idx >= 0) { orders[idx].status = "CANCELLED"; saveOrders(orders); }
    return orders[idx];
  },
  restaurantOrders: async (status?: string) => {
    await delay();
    const u = currentUser();
    const rests = getRestaurants();
    const mine = rests.find((r: any) => r.ownerId === u?.id);
    if (!mine) return [];
    const menus = getMenuItems();
    const restaurantMenu = menus[mine.id] || [];
    let orders = getOrders().filter((o: any) => o.restaurantId === mine.id);
    if (status) orders = orders.filter((o: any) => o.status === status);
    // attach menuItem info to items
    return orders.map((o: any) => ({
      ...o,
      items: (o.items || []).map((item: any) => ({
        ...item,
        menuItem: restaurantMenu.find((m: any) => m.id === item.menuItemId) || { name: item.name || "Article", price: item.price || 0 },
      })),
    }));
  },
  updateStatus: async (id: string, status: string) => {
    await delay();
    const orders = getOrders();
    const idx = orders.findIndex((o: any) => o.id === id);
    if (idx >= 0) { orders[idx].status = status; saveOrders(orders); return orders[idx]; }
    throw { status: 404, message: "Commande introuvable" };
  },
};

// ─── Reviews ───────────────────────────────────────────────────────────────────

export const reviewApi = {
  byRestaurant: async (restaurantId: string) => {
    await delay();
    return ls<any[]>(`mock_reviews_${restaurantId}`, [
      { id: "rv1", rating: 5, comment: "Excellent, très rapide !", user: { name: "Marie" }, createdAt: new Date().toISOString() },
      { id: "rv2", rating: 4, comment: "Très bon, je recommande.", user: { name: "Thomas" }, createdAt: new Date().toISOString() },
    ]);
  },
  create: async (restaurantId: string, data: any) => {
    await delay();
    const u = currentUser();
    const review = { id: uid(), ...data, user: { name: u?.name || "Anonyme" }, createdAt: new Date().toISOString() };
    const reviews = ls<any[]>(`mock_reviews_${restaurantId}`, []);
    reviews.unshift(review);
    lsSet(`mock_reviews_${restaurantId}`, reviews);
    return review;
  },
};

// ─── Notifications ─────────────────────────────────────────────────────────────

export const notificationApi = {
  list: async () => {
    await delay(50);
    return ls<any[]>("mock_notifs", [
      { id: "n1", type: "ORDER_UPDATE", message: "Bienvenue sur FAST ! 🎉", read: false, createdAt: new Date().toISOString() },
    ]);
  },
  create: async (data: any) => { await delay(50); return { id: uid(), ...data, read: false, createdAt: new Date().toISOString() }; },
  readAll: async () => { await delay(50); const n = ls<any[]>("mock_notifs", []); n.forEach((x) => (x.read = true)); lsSet("mock_notifs", n); return null; },
  read: async (id: string) => { await delay(50); return null; },
  delete: async (id: string) => { await delay(50); return null; },
  deleteAll: async () => { await delay(50); lsSet("mock_notifs", []); return null; },
};

// ─── Stats ─────────────────────────────────────────────────────────────────────

export const statsApi = {
  get: async () => {
    await delay();
    const u = currentUser();
    const rests = getRestaurants();
    const mine = rests.find((r: any) => r.ownerId === u?.id);
    const orders = getOrders().filter((o: any) => o.restaurantId === mine?.id);
    const completed = orders.filter((o: any) => o.status === "COMPLETED");
    const cancelled = orders.filter((o: any) => o.status === "CANCELLED");
    const revenue = completed.reduce((sum: number, o: any) => sum + (o.total || 0), 0);
    const menus = getMenuItems();
    const restaurantMenu = mine ? (menus[mine.id] || []) : [];
    // daily orders last 7 days
    const dailyOrders = Array.from({ length: 7 }, (_, i) => {
      const d = new Date(); d.setDate(d.getDate() - (6 - i));
      const dateStr = d.toISOString().slice(0, 10);
      const count = orders.filter((o: any) => o.createdAt?.slice(0, 10) === dateStr).length;
      return { date: dateStr, count };
    });
    // popular items
    const itemCounts: Record<string, number> = {};
    orders.forEach((o: any) => (o.items || []).forEach((it: any) => { itemCounts[it.menuItemId] = (itemCounts[it.menuItemId] || 0) + (it.quantity || 1); }));
    const popularItems = Object.entries(itemCounts)
      .map(([id, totalSold]) => ({ id, name: restaurantMenu.find((m: any) => m.id === id)?.name || "Article", totalSold }))
      .sort((a: any, b: any) => b.totalSold - a.totalSold)
      .slice(0, 5);
    const now = new Date();
    const monthOrders = orders.filter((o: any) => { const d = new Date(o.createdAt); return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear(); }).length;
    return {
      totalOrders: orders.length,
      monthOrders,
      completedOrders: completed.length,
      revenue: parseFloat(revenue.toFixed(2)),
      averageRating: mine?.rating || 0,
      cancellationRate: orders.length > 0 ? Math.round((cancelled.length / orders.length) * 100) : 0,
      dailyOrders,
      popularItems,
    };
  },
};

// ─── Groups ────────────────────────────────────────────────────────────────────

export const groupApi = {
  create: async (data: any) => { await delay(); const g = { id: uid(), code: Math.random().toString(36).slice(2, 8).toUpperCase(), ...data, createdAt: new Date().toISOString() }; lsSet("mock_group_" + g.id, g); return g; },
  join: async (code: string) => { await delay(); return { id: uid(), code }; },
  mine: async () => { await delay(); return []; },
  get: async (id: string) => { await delay(); return ls("mock_group_" + id, null); },
  leave: async (id: string) => { await delay(); return null; },
};

// ─── Deliveries ────────────────────────────────────────────────────────────────

export const deliveryApi = {
  available: async () => { await delay(); return []; },
  active: async () => { await delay(); return []; },
  accept: async (id: string) => { await delay(); return null; },
  updateStatus: async (id: string, status: string) => { await delay(); return null; },
  generate: async () => { await delay(); return null; },
};

// ─── Health ────────────────────────────────────────────────────────────────────

export const healthApi = {
  check: async () => { await delay(50); return { status: "ok" }; },
};

export default function apiFetch() { return Promise.resolve(null); }
