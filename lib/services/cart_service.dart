import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/cart.dart';

// Quantity per product id for the local cart, shared between the product
// detail screen's "Add to Cart" button and CartScreen so repeated taps on
// the same product accumulate instead of being tracked separately. Starts
// empty regardless of whatever cart data the API returns.
final ValueNotifier<Map<int, int>> cartQuantities =
    ValueNotifier<Map<int, int>>({});

// Bumps (or starts at 1) the quantity for [productId]. Used both by "Add to
// Cart" and by CartScreen's own + button.
void bumpCartQuantity(int productId) {
  final updated = Map<int, int>.from(cartQuantities.value);
  updated[productId] = (updated[productId] ?? 0) + 1;
  cartQuantities.value = updated;
}

// Sets an explicit quantity for [productId]; a quantity <= 0 removes it from
// the cart entirely.
void setCartQuantity(int productId, int quantity) {
  final updated = Map<int, int>.from(cartQuantities.value);
  if (quantity <= 0) {
    updated.remove(productId);
  } else {
    updated[productId] = quantity;
  }
  cartQuantities.value = updated;
}

// Seeds [productId] to [defaultQuantity] only if it isn't already tracked,
// so CartScreen can show items from the API's cart without clobbering
// quantities already bumped via "Add to Cart".
void seedCartQuantity(int productId, int defaultQuantity) {
  if (cartQuantities.value.containsKey(productId)) return;
  final updated = Map<int, int>.from(cartQuantities.value);
  updated[productId] = defaultQuantity;
  cartQuantities.value = updated;
}

class CartService {
  Future<List<Cart>> getAllCarts() async {
    final response = await http.get(Uri.parse('$host/carts'));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List cartsJson = data['carts'] ?? [];
      return cartsJson.map((json) => Cart.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load carts');
    }
  }

  // Enhancement 3: https://dummyjson.com/docs/carts - GET /carts/user/{userId}
  // returns the cart for a specific user by their userId, if the user has no cart, returns null.
  Future<Cart?> getCartByUserId(int userId) async {
    final response = await http.get(Uri.parse('$host/carts/user/$userId'));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List cartsJson = data['carts'] ?? [];
      if (cartsJson.isEmpty) return null;
      return Cart.fromJson(cartsJson.first);
    } else {
      throw Exception('Failed to load cart for user $userId');
    }
  }

  // Enhancement 3: https://dummyjson.com/carts/add - POST /carts/add
  // passes userId and a list of products to add to the cart, each product being a map with keys "id" and "quantity"
  Future<Cart> addToCart(
    int userId,
    List<Map<String, dynamic>> products,
  ) async {
    final response = await http.post(
      Uri.parse('$host/carts/add'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'products': products}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Cart.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to add to cart');
    }
  }
}
