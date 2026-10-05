class ApiConfig {
  // Production backend (Vercel)
  static const String baseUrl = String.fromEnvironment(
    'FAST_API_URL',
    defaultValue: 'https://backend-six-iota-69.vercel.app/api',
  );
  static Duration timeout = const Duration(seconds: 30);

  // Auth
  static const String login = '/auth/login';
  static const String googleAuth = '/auth/google';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
  static const String updateProfile = '/auth/profile';
  static const String changePassword = '/auth/change-password';
  static const String logout = '/auth/logout';
  static const String deleteAccount = '/auth/account';

  // Restaurants
  static const String restaurants = '/restaurants';
  static String restaurant(String id) => '/restaurants/$id';
  static const String myRestaurant = '/restaurants/account/mine';
  static const String toggleRush = '/restaurants/toggle-rush';
  static String updateRestaurant(String id) => '/restaurants/$id';

  // Menu
  static String menuByRestaurant(String id) => '/menu/restaurant/$id';
  static String menuItem(String id) => '/menu/$id';
  static String managedMenuByRestaurant(String id) => '/menu/restaurant/$id/manage';
  static String scanMenu(String restaurantId) =>
      '/menu/restaurant/$restaurantId/scan';
  static String menuItemSupplements(String menuItemId) =>
      '/menu/$menuItemId/supplements';
  static String menuSupplement(String id) => '/menu/supplements/$id';

  // Orders
  static const String orders = '/orders';
  static const String myOrders = '/orders/mine';
  static String cancelOrder(String id) => '/orders/$id/cancel';
  static const String restaurantOrders = '/orders/restaurant';
  static String updateOrderStatus(String id) => '/orders/$id/status';
  static String order(String id) => '/orders/$id';
  static String updateOrderTracking(String id) => '/orders/$id/tracking';
  static String verifyPickup(String id) => '/orders/$id/verify-pickup';
  static String orderDelivery(String orderId) => '/deliveries/order/$orderId';

  // Payments
  static const String createCheckoutSession = '/payments/checkout-session';
  static String confirmCheckoutSession(String sessionId) =>
      '/payments/checkout-session/$sessionId/confirm';
  static const String stripeConnectAccountLink =
      '/payments/connect/account-link';
  static const String stripeConnectStatus = '/payments/connect/status';
  static const String paymentMethods = '/payments/methods';
  static const String setupPaymentMethod = '/payments/methods/setup';
  static String paymentMethod(String id) => '/payments/methods/$id';
  static const String addresses = '/addresses';
  static String savedAddress(String id) => '/addresses/$id';

  // Reviews
  static String reviewsByRestaurant(String id) => '/reviews/restaurant/$id';

  // Notifications
  static const String notifications = '/notifications';
  static const String readAll = '/notifications/read-all';
  static String readNotification(String id) => '/notifications/$id/read';
  static String deleteNotification(String id) => '/notifications/$id';

  // Staff / cook accounts (restaurant owner only)
  static const String staff = '/staff';
  static String staffMember(String id) => '/staff/$id';

  // Stats
  static const String stats = '/stats';
  static const String statsExport = '/stats/export';

  // Groups
  static const String groups = '/groups';
  static const String joinGroup = '/groups/join';
  static const String myGroups = '/groups/mine';
  static String group(String id) => '/groups/$id';
  static String leaveGroup(String id) => '/groups/$id/leave';
  static String updateGroupMember(String id) => '/groups/$id/member';
  static String lockGroup(String id) => '/groups/$id/lock';
  static String submitGroup(String id) => '/groups/$id/submit';
  static String groupCart(String id) => '/groups/$id/cart';

  // Deliveries
  static const String availableDeliveries = '/deliveries/available';
  static const String activeDelivery = '/deliveries/active';
  static String acceptDelivery(String id) => '/deliveries/$id/accept';
  static String updateDeliveryStatus(String id) => '/deliveries/$id/status';

  // Driver profile
  static const String driverProfile = '/drivers/me';
  static const String driverAvailability = '/drivers/availability';
  static const String driverSchedules = '/drivers/schedules';
}
