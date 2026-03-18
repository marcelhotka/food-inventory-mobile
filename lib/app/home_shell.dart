import 'package:flutter/material.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/food_items/presentation/food_items_screen.dart';
import '../features/households/domain/household.dart';
import '../features/recipes/presentation/recipes_screen.dart';
import '../features/shopping_list/presentation/shopping_list_screen.dart';

class HomeShell extends StatefulWidget {
  final AuthRepository authRepository;
  final Household household;

  const HomeShell({
    super.key,
    required this.authRepository,
    required this.household,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  int _pantryRefreshToken = 0;
  int _shoppingListRefreshToken = 0;
  int _recipesRefreshToken = 0;
  int _mealPlanRefreshToken = 0;
  String? _focusedRecipeId;

  void _openTab(int index) {
    setState(() {
      _selectedIndex = index;
      if (index != 3) {
        _focusedRecipeId = null;
      }
    });
  }

  void _openRecipe(String recipeId) {
    setState(() {
      _selectedIndex = 3;
      _focusedRecipeId = recipeId;
    });
  }

  void _notifyShoppingListChanged() {
    setState(() {
      _shoppingListRefreshToken++;
    });
  }

  void _notifyPantryChanged() {
    setState(() {
      _pantryRefreshToken++;
      _recipesRefreshToken++;
    });
  }

  void _notifyMealPlanChanged() {
    setState(() {
      _mealPlanRefreshToken++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        household: widget.household,
        pantryRefreshToken: _pantryRefreshToken,
        shoppingListRefreshToken: _shoppingListRefreshToken,
        onOpenPantry: () => _openTab(1),
        onOpenShoppingList: () => _openTab(2),
        onOpenRecipes: () => _openTab(3),
        onOpenRecipe: _openRecipe,
        onShoppingListChanged: _notifyShoppingListChanged,
        recipesRefreshToken: _recipesRefreshToken,
        mealPlanRefreshToken: _mealPlanRefreshToken,
      ),
      FoodItemsScreen(
        authRepository: widget.authRepository,
        household: widget.household,
        onPantryChanged: _notifyPantryChanged,
        onShoppingListChanged: _notifyShoppingListChanged,
        refreshToken: _pantryRefreshToken,
      ),
      ShoppingListScreen(
        authRepository: widget.authRepository,
        household: widget.household,
        refreshToken: _shoppingListRefreshToken,
      ),
      RecipesScreen(
        household: widget.household,
        onShoppingListChanged: _notifyShoppingListChanged,
        onPantryChanged: _notifyPantryChanged,
        onMealPlanChanged: _notifyMealPlanChanged,
        refreshToken: _recipesRefreshToken,
        focusedRecipeId: _focusedRecipeId,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) {
          setState(() {
            _selectedIndex = value;
            if (value != 3) {
              _focusedRecipeId = null;
            }
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.kitchen_outlined),
            selectedIcon: Icon(Icons.kitchen),
            label: 'Pantry',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Shopping List',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Recipes',
          ),
        ],
      ),
    );
  }
}
