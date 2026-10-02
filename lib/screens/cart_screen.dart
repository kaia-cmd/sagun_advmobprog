import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/cart.dart';
import '../services/cart_service.dart';
import '../services/product_service.dart';
import '../widgets/custom_text.dart';
import 'detail_screen.dart';

// Enhancement 1: cart screen rendering the /carts endpoint.
// Enhancement 3: shows only the signed-in user's cart via GET
// /carts/user/{id} (see CartService.getCartByUserId), using the userId
// threaded down from HomeScreen (sourced from the saved user data) instead
// of a hardcoded id.
class CartScreen extends StatefulWidget {
  final int userId;
  const CartScreen({super.key, required this.userId});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Future<Cart?> _cartFuture;

  @override
  void initState() {
    super.initState();
    // fetch the cart for the signed-in user when the screen is initialized,
    // then seed the shared quantities so items already in the API's cart
    // show up here even before any "Add to Cart" tap.
    _cartFuture = CartService().getCartByUserId(widget.userId).then((cart) {
      for (final item in cart?.products ?? <CartProduct>[]) {
        seedCartQuantity(item.id, 1);
      }
      return cart;
    });
  }

  double _lineTotal(CartProduct item, int qty) {
    final rawTotal = item.price * qty;
    return rawTotal - (rawTotal * item.discountPercentage / 100);
  }

  @override
  Widget build(BuildContext context) {
    // No AppBar here — CartScreen is used as a tab inside HomeScreen, whose
    // own AppBar already shows the "Cart" title when this tab is active.
    return Scaffold(
      body: FutureBuilder<Cart?>(
        future: _cartFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: CustomText(
                text: 'Error: ${snapshot.error}',
                fontSize: 14.sp,
              ),
            );
          }

          final cart = snapshot.data;

          return ValueListenableBuilder<Map<int, int>>(
            valueListenable: cartQuantities,
            builder: (context, quantities, _) {
              final products = cart == null
                  ? <CartProduct>[]
                  : cart.products
                        .where((p) => quantities.containsKey(p.id))
                        .toList();
              if (products.isEmpty) {
                return Center(
                  child: CustomText(
                    text: 'Your cart is empty.',
                    fontSize: 14.sp,
                  ),
                );
              }

              final subtotal = products.fold<double>(
                0,
                (sum, item) => sum + _lineTotal(item, quantities[item.id]!),
              );

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.all(16.r),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final item = products[index];
                        final qty = quantities[item.id]!;

                        return GestureDetector(
                          // Enhancement 1: cart items are clickable and route
                          // to the same detail_screen.dart used by
                          // ProductScreen, reusing it via the productId-only
                          // constructor path.
                          onTap: () async {
                            final product = await ProductService()
                                .getProductById(item.id);

                            if (!context.mounted) return;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetailScreen(
                                  product: product,
                                  userId: widget.userId,
                                ),
                              ),
                            );
                          },
                          child: Card(
                            margin: EdgeInsets.only(bottom: 12.h),
                            child: Padding(
                              padding: EdgeInsets.all(8.r),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8.r),
                                    child: Image.network(
                                      item.thumbnail,
                                      width: 56.w,
                                      height: 56.w,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          Icon(Icons.image, size: 24.sp),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CustomText(
                                          text: item.title,
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.bold,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4.h),
                                        CustomText(
                                          text:
                                              '\$${item.price.toStringAsFixed(2)}',
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        CustomText(
                                          text:
                                              '${item.discountPercentage.toStringAsFixed(0)}% off · \$${_lineTotal(item, qty).toStringAsFixed(2)} total',
                                          fontSize: 11.sp,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Enhancement 4: removes this product
                                      // from the cart entirely.
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          Icons.delete_outline,
                                          size: 20.sp,
                                          color: Colors.grey,
                                        ),
                                        onPressed: () {
                                          setCartQuantity(item.id, 0);
                                        },
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(
                                          Icons.add_circle,
                                          color: Colors.amber,
                                        ),
                                        onPressed: () {
                                          bumpCartQuantity(item.id);
                                        },
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 2.h,
                                        ),
                                        child: CustomText(
                                          text: '$qty',
                                          fontSize: 13.sp,
                                        ),
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(
                                          Icons.remove_circle,
                                          color: Colors.grey,
                                        ),
                                        onPressed: () {
                                          // Enhancement 4: quantity hitting 0
                                          // removes the item from the cart
                                          // instead of leaving a 0-qty row.
                                          setCartQuantity(item.id, qty - 1);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const CustomText(text: 'Subtotal:', fontSize: 14),
                            CustomText(
                              text: '\$${subtotal.toStringAsFixed(2)}',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Order confirmed!'),
                                ),
                              );
                            },
                            child: const CustomText(
                              text: 'Confirm Order',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
