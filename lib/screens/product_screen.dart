import 'package:flutter/material.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/product.dart';
import '../services/cart_service.dart';
import '../services/product_service.dart';
import '../widgets/custom_text.dart';
import 'detail_screen.dart';

// Enhancement 3: userId is the signed-in user's id (from HomeScreen, sourced
// from the SharedPreferences-saved user), used to fetch/merge that user's
// cart with the product grid and to thread into DetailScreen's "Add to Cart".
class ProductScreen extends StatefulWidget {
  final int userId;
  const ProductScreen({super.key, required this.userId});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final ProductService _productService = ProductService();
  final TextEditingController _searchController = TextEditingController();
  final CartService _cartService = CartService();

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _productService.getAllProducts();
      final cart = await _cartService.getCartByUserId(widget.userId);

      final mergedProducts = [...products];
      final existingIds = products.map((product) => product.id).toSet();

      for (final cartItem in cart?.products ?? []) {
        if (existingIds.contains(cartItem.id)) continue;

        try {
          final product = await _productService.getProductById(cartItem.id);
          mergedProducts.add(product);
          existingIds.add(product.id);
        } catch (_) {}
      }

      final cartOrder = <int, int>{};

      for (var index = 0; index < (cart?.products.length ?? 0); index++) {
        cartOrder[cart!.products[index].id] = index;
      }

      mergedProducts.sort((a, b) {
        final aOrder = cartOrder[a.id];
        final bOrder = cartOrder[b.id];

        if (aOrder == null && bOrder == null) return 0;
        if (aOrder == null) return 1;
        if (bOrder == null) return -1;

        return aOrder.compareTo(bOrder);
      });

      if (!mounted) return;

      setState(() {
        _allProducts = mergedProducts;
        _filteredProducts = mergedProducts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Failed to load products: $e';
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredProducts = query.isEmpty
          ? _allProducts
          : _allProducts
                .where((p) => p.title.toLowerCase().contains(query))
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(12.r),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _searchController.clear,
                    );
                  },
                ),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 0.h),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: CustomText(text: _error!, fontSize: 14.sp),
      );
    }
    if (_filteredProducts.isEmpty) {
      return Center(
        child: CustomText(text: 'No products found', fontSize: 14.sp),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      itemCount: _filteredProducts.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12.h,
        crossAxisSpacing: 12.w,
        childAspectRatio: 0.68,
      ),
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return _ProductCard(product: product, userId: widget.userId);
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final int userId;

  const _ProductCard({required this.product, required this.userId});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12.r),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailScreen(product: product, userId: userId),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade300),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Image.network(
                product.thumbnail,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: Colors.grey.shade300,
                  child: Icon(Icons.image, size: 32.sp),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    text: product.title,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  CustomText(
                    text: '\$${product.price.toStringAsFixed(2)}',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
