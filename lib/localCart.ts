const CART_KEY = "fast_cart";
const FAVORITES_KEY = "fast_favorites";

export interface CartItem {
  id: string;
  menuItemId: string;
  restaurantId: string;
  restaurantName: string;
  name: string;
  price: number;
  quantity: number;
  imageUrl?: string;
  options?: string[];
  notes?: string;
}

function getStorage(): Storage | null {
  if (typeof window === "undefined") return null;
  return window.localStorage;
}

export function getCart(): CartItem[] {
  const storage = getStorage();
  if (!storage) return [];
  try {
    return JSON.parse(storage.getItem(CART_KEY) || "[]");
  } catch {
    return [];
  }
}

export function saveCart(cart: CartItem[]) {
  const storage = getStorage();
  if (!storage) return;
  storage.setItem(CART_KEY, JSON.stringify(cart));
}

/**
 * Two lines are only mergeable when they are the same dish *and* carry the same
 * options and notes — otherwise a "no onions" line would silently absorb a
 * regular one.
 */
function lineSignature(item: Pick<CartItem, "menuItemId" | "restaurantId" | "options" | "notes">) {
  const options = [...(item.options || [])].sort().join("|");
  return `${item.restaurantId}::${item.menuItemId}::${options}::${item.notes || ""}`;
}

export function addToCart(item: Omit<CartItem, "id" | "quantity"> & { quantity?: number }) {
  const cart = getCart();
  const signature = lineSignature(item);
  const existing = cart.find((c) => lineSignature(c) === signature);
  if (existing) {
    existing.quantity += item.quantity || 1;
  } else {
    cart.push({
      ...item,
      options: item.options || [],
      notes: item.notes || "",
      id: `${item.menuItemId}-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
      quantity: item.quantity || 1,
    });
  }
  saveCart(cart);
  return cart;
}

export function updateCartItemNotes(id: string, notes: string) {
  const cart = getCart();
  const item = cart.find((c) => c.id === id);
  if (item) item.notes = notes;
  saveCart(cart);
  return cart;
}

/** Distinct restaurants currently represented in the cart. */
export function getCartRestaurants(cart: CartItem[]): { id: string; name: string }[] {
  const seen = new Map<string, string>();
  for (const item of cart) {
    if (!seen.has(item.restaurantId)) seen.set(item.restaurantId, item.restaurantName);
  }
  return Array.from(seen, ([id, name]) => ({ id, name }));
}

/** Drops every line that does not belong to `restaurantId`. */
export function keepOnlyRestaurant(restaurantId: string) {
  const cart = getCart().filter((c) => c.restaurantId === restaurantId);
  saveCart(cart);
  return cart;
}

export function updateCartQuantity(id: string, quantity: number) {
  let cart = getCart();
  if (quantity <= 0) {
    cart = cart.filter((c) => c.id !== id);
  } else {
    const item = cart.find((c) => c.id === id);
    if (item) item.quantity = quantity;
  }
  saveCart(cart);
  return cart;
}

export function removeFromCart(id: string) {
  const cart = getCart().filter((c) => c.id !== id);
  saveCart(cart);
  return cart;
}

export function clearCart() {
  saveCart([]);
}

export function getCartTotal(cart: CartItem[]) {
  return cart.reduce((sum, c) => sum + (c.price || 0) * (c.quantity || 1), 0);
}

export function getCartCount(cart: CartItem[]) {
  return cart.reduce((sum, c) => sum + (c.quantity || 1), 0);
}

export function getFavorites(): string[] {
  const storage = getStorage();
  if (!storage) return [];
  try {
    return JSON.parse(storage.getItem(FAVORITES_KEY) || "[]");
  } catch {
    return [];
  }
}

export function toggleFavorite(restaurantId: string) {
  const favorites = getFavorites();
  const index = favorites.indexOf(restaurantId);
  if (index >= 0) {
    favorites.splice(index, 1);
  } else {
    favorites.push(restaurantId);
  }
  const storage = getStorage();
  if (storage) storage.setItem(FAVORITES_KEY, JSON.stringify(favorites));
  return favorites;
}

export function isFavorite(restaurantId: string) {
  return getFavorites().includes(restaurantId);
}
