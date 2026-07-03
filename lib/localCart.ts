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

export function addToCart(item: Omit<CartItem, "id" | "quantity"> & { quantity?: number }) {
  const cart = getCart();
  const existing = cart.find(
    (c) => c.menuItemId === item.menuItemId && c.restaurantId === item.restaurantId
  );
  if (existing) {
    existing.quantity += item.quantity || 1;
  } else {
    cart.push({
      ...item,
      id: `${item.menuItemId}-${Date.now()}`,
      quantity: item.quantity || 1,
    } as CartItem);
  }
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
