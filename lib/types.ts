export type UserRole = "CLIENT" | "RESTAURANT" | "DELIVERER" | "ADMIN";

export type OrderStatus =
  | "PLACED"
  | "PREPARING"
  | "READY_FOR_PICKUP"
  | "COMPLETED"
  | "CANCELLED";

export type DeliveryStatus =
  | "PENDING"
  | "ACCEPTED"
  | "PICKED_UP"
  | "DELIVERED"
  | "CANCELLED";

export interface DietaryOption {
  option: string;
}

export interface User {
  id: string;
  email: string;
  name: string;
  phone?: string | null;
  role: UserRole;
  points?: number;
  isOnline?: boolean;
  createdAt?: string;
}

export interface Restaurant {
  id: string;
  name: string;
  description?: string;
  image?: string;
  address?: string;
  city?: string;
  phone?: string;
  cuisineType?: string;
  category?: string;
  rating?: number;
  reviewsCount?: number;
  normalPrepTime?: number;
  rushPrepTime?: number;
  pickupPrepTime?: number;
  isActive?: boolean;
  isRushMode?: boolean;
  dietaryOptions?: DietaryOption[];
  menuItems?: MenuItem[];
  ownerId?: string;
}

export interface MenuItem {
  id: string;
  restaurantId: string;
  name: string;
  description?: string;
  price: number;
  image?: string;
  category?: string;
  isAvailable?: boolean;
  isPopular?: boolean;
  rating?: number;
  dietaryTags?: DietaryOption[];
}

export interface OrderItem {
  id?: string;
  menuItemId: string;
  quantity: number;
  price?: number;
  selectedOptions?: string[];
  allergyNotes?: string;
  menuItem?: Pick<MenuItem, "name" | "price"> & Partial<MenuItem>;
}

export interface Order {
  id: string;
  orderNumber?: string;
  userId?: string;
  restaurantId: string;
  restaurant?: Pick<Restaurant, "id" | "name" | "image" | "address"> & Partial<Restaurant>;
  user?: Pick<User, "id" | "name" | "phone"> & Partial<User>;
  status: OrderStatus;
  items: OrderItem[];
  subtotal?: number;
  serviceFee?: number;
  total: number;
  allergyNotes?: string;
  userWalkTimeMin?: number;
  arrivalMinutes?: number;
  createdAt: string;
  updatedAt?: string;
}

export interface Review {
  id: string;
  restaurantId: string;
  userId: string;
  user?: Pick<User, "id" | "name">;
  rating: number;
  comment?: string;
  createdAt: string;
}

export interface AppNotification {
  id: string;
  userId: string;
  title: string;
  body?: string;
  isRead: boolean;
  createdAt: string;
}

export interface GroupMember {
  id: string;
  userId: string;
  name: string;
  isReady?: boolean;
  itemsCount?: number;
}

export interface GroupOrder {
  id: string;
  code: string;
  hostId: string;
  restaurantId?: string;
  members: GroupMember[];
  status?: string;
  createdAt: string;
}

export interface Delivery {
  id: string;
  orderId: string;
  order?: Order;
  delivererId?: string;
  status: DeliveryStatus;
  pickupAddress?: string;
  dropoffAddress?: string;
  earnings?: number;
  createdAt: string;
}

export interface RestaurantStats {
  totalOrders: number;
  monthOrders: number;
  completedOrders: number;
  cancelledOrders?: number;
  totalRevenue: number;
  averageRating: number;
  cancellationRate: number;
  dailyOrders?: { date: string; count: number }[];
  popularItems?: { name: string; count: number }[];
}

export interface ApiError {
  status: number;
  message: string;
}
