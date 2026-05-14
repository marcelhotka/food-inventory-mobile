String defaultPantryCategory(String itemKey) {
  switch (itemKey) {
    case 'milk':
    case 'cheese':
    case 'yogurt':
    case 'butter':
    case 'cream':
      return 'dairy';
    case 'eggs':
      return 'other';
    case 'ham':
    case 'chicken':
      return 'meat';
    case 'peas':
      return 'frozen';
    case 'bread':
    case 'pasta':
    case 'rice':
    case 'beans':
    case 'flour':
      return 'grains';
    case 'tomato':
      return 'produce';
    default:
      return 'other';
  }
}

String defaultPantryStorage(String itemKey) {
  switch (itemKey) {
    case 'milk':
    case 'cheese':
    case 'eggs':
    case 'yogurt':
    case 'butter':
    case 'cream':
    case 'ham':
    case 'chicken':
      return 'fridge';
    case 'peas':
      return 'freezer';
    default:
      return 'pantry';
  }
}
