import 'package:flutter/material.dart';

import 'localization/app_locale.dart';
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
  int _pantryExpiringSoonOpenToken = 0;
  String? _focusedRecipeId;
  RecipeFilter _recipesInitialFilter = RecipeFilter.all;

  void _openTab(int index) {
    setState(() {
      _selectedIndex = index;
      if (index != 3) {
        _focusedRecipeId = null;
        _recipesInitialFilter = RecipeFilter.all;
      }
    });
  }

  void _openRecipe(String recipeId) {
    setState(() {
      _selectedIndex = 3;
      _focusedRecipeId = recipeId;
      _recipesInitialFilter = RecipeFilter.all;
    });
  }

  void _openSafeRecipes() {
    setState(() {
      _selectedIndex = 3;
      _focusedRecipeId = null;
      _recipesInitialFilter = RecipeFilter.safeForMe;
    });
  }

  void _openQuickRecipes() {
    setState(() {
      _selectedIndex = 3;
      _focusedRecipeId = null;
      _recipesInitialFilter = RecipeFilter.under30Minutes;
    });
  }

  void _openPantryExpiringSoon() {
    setState(() {
      _selectedIndex = 1;
      _pantryExpiringSoonOpenToken++;
      _focusedRecipeId = null;
      _recipesInitialFilter = RecipeFilter.all;
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
        onOpenExpiringSoon: _openPantryExpiringSoon,
        onOpenShoppingList: () => _openTab(2),
        onOpenRecipes: () => _openTab(3),
        onOpenSafeRecipes: _openSafeRecipes,
        onOpenQuickRecipes: _openQuickRecipes,
        onOpenRecipe: _openRecipe,
        onPantryChanged: _notifyPantryChanged,
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
        expiringSoonOpenToken: _pantryExpiringSoonOpenToken,
      ),
      ShoppingListScreen(
        authRepository: widget.authRepository,
        household: widget.household,
        refreshToken: _shoppingListRefreshToken,
        onShoppingListChanged: _notifyShoppingListChanged,
      ),
      RecipesScreen(
        household: widget.household,
        onShoppingListChanged: _notifyShoppingListChanged,
        onPantryChanged: _notifyPantryChanged,
        onMealPlanChanged: _notifyMealPlanChanged,
        refreshToken: _recipesRefreshToken,
        focusedRecipeId: _focusedRecipeId,
        initialFilter: _recipesInitialFilter,
      ),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) {
          setState(() {
            _selectedIndex = value;
            if (value != 3) {
              _focusedRecipeId = null;
              _recipesInitialFilter = RecipeFilter.all;
            }
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: context.tr(en: 'Dashboard', sk: 'Prehľad'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.kitchen_outlined),
            selectedIcon: const Icon(Icons.kitchen),
            label: context.tr(en: 'Pantry', sk: 'Špajza'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.shopping_cart_outlined),
            selectedIcon: const Icon(Icons.shopping_cart),
            label: context.tr(en: 'Shopping List', sk: 'Nákupný zoznam'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: context.tr(en: 'Recipes', sk: 'Recepty'),
          ),
        ],
      ),
    );
  }
}
