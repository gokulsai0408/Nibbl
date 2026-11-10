import '../../domain/entities/food.dart';
import '../../domain/entities/macros.dart';

/// Built-in food database (approximate values, per stated serving).
const List<Food> builtInFoods = [
  // Breakfast staples
  Food(id: 'egg', name: 'Egg (large)', emoji: '🥚', servingLabel: '1 egg', servingGrams: 50, macros: Macros(kcal: 72, protein: 6.3, carbs: 0.4, fat: 4.8)),
  Food(id: 'scrambled_eggs', name: 'Scrambled eggs', emoji: '🍳', servingLabel: '2 eggs', servingGrams: 120, macros: Macros(kcal: 200, protein: 13, carbs: 2, fat: 15)),
  Food(id: 'toast_white', name: 'White toast', emoji: '🍞', servingLabel: '1 slice', servingGrams: 30, macros: Macros(kcal: 80, protein: 2.7, carbs: 15, fat: 1)),
  Food(id: 'toast_wholegrain', name: 'Wholegrain toast', emoji: '🍞', servingLabel: '1 slice', servingGrams: 35, macros: Macros(kcal: 90, protein: 4.5, carbs: 15, fat: 1.2)),
  Food(id: 'butter', name: 'Butter', emoji: '🧈', servingLabel: '1 tsp', servingGrams: 5, macros: Macros(kcal: 36, protein: 0, carbs: 0, fat: 4.1)),
  Food(id: 'peanut_butter', name: 'Peanut butter', emoji: '🥜', servingLabel: '1 tbsp', servingGrams: 16, macros: Macros(kcal: 94, protein: 3.5, carbs: 3.2, fat: 8)),
  Food(id: 'oatmeal', name: 'Oatmeal (cooked)', emoji: '🥣', servingLabel: '1 bowl', servingGrams: 240, macros: Macros(kcal: 160, protein: 6, carbs: 28, fat: 3)),
  Food(id: 'greek_yogurt', name: 'Greek yogurt (plain, 2%)', emoji: '🥛', servingLabel: '1 cup', servingGrams: 200, macros: Macros(kcal: 146, protein: 20, carbs: 8, fat: 4)),
  Food(id: 'granola', name: 'Granola', emoji: '🥣', servingLabel: '½ cup', servingGrams: 50, macros: Macros(kcal: 230, protein: 5, carbs: 32, fat: 9)),
  Food(id: 'pancakes', name: 'Pancakes', emoji: '🥞', servingLabel: '3 medium', servingGrams: 150, macros: Macros(kcal: 350, protein: 9, carbs: 55, fat: 10)),
  Food(id: 'bacon', name: 'Bacon', emoji: '🥓', servingLabel: '2 slices', servingGrams: 16, macros: Macros(kcal: 86, protein: 6, carbs: 0.2, fat: 6.7)),
  Food(id: 'croissant', name: 'Croissant', emoji: '🥐', servingLabel: '1 medium', servingGrams: 57, macros: Macros(kcal: 231, protein: 4.7, carbs: 26, fat: 12)),
  Food(id: 'avocado_toast', name: 'Avocado toast', emoji: '🥑', servingLabel: '1 slice', servingGrams: 110, macros: Macros(kcal: 230, protein: 6, carbs: 22, fat: 14)),

  // Fruit & veg
  Food(id: 'banana', name: 'Banana', emoji: '🍌', servingLabel: '1 medium', servingGrams: 118, macros: Macros(kcal: 105, protein: 1.3, carbs: 27, fat: 0.4)),
  Food(id: 'apple', name: 'Apple', emoji: '🍎', servingLabel: '1 medium', servingGrams: 182, macros: Macros(kcal: 95, protein: 0.5, carbs: 25, fat: 0.3)),
  Food(id: 'orange', name: 'Orange', emoji: '🍊', servingLabel: '1 medium', servingGrams: 131, macros: Macros(kcal: 62, protein: 1.2, carbs: 15, fat: 0.2)),
  Food(id: 'berries', name: 'Mixed berries', emoji: '🫐', servingLabel: '1 cup', servingGrams: 150, macros: Macros(kcal: 70, protein: 1, carbs: 17, fat: 0.5)),
  Food(id: 'strawberries', name: 'Strawberries', emoji: '🍓', servingLabel: '1 cup', servingGrams: 150, macros: Macros(kcal: 48, protein: 1, carbs: 11.5, fat: 0.5)),
  Food(id: 'grapes', name: 'Grapes', emoji: '🍇', servingLabel: '1 cup', servingGrams: 150, macros: Macros(kcal: 104, protein: 1.1, carbs: 27, fat: 0.2)),
  Food(id: 'avocado', name: 'Avocado', emoji: '🥑', servingLabel: '½ fruit', servingGrams: 75, macros: Macros(kcal: 120, protein: 1.5, carbs: 6.4, fat: 11)),
  Food(id: 'broccoli', name: 'Broccoli (steamed)', emoji: '🥦', servingLabel: '1 cup', servingGrams: 156, macros: Macros(kcal: 55, protein: 3.7, carbs: 11, fat: 0.6)),
  Food(id: 'side_salad', name: 'Side salad', emoji: '🥗', servingLabel: '1 bowl', servingGrams: 120, macros: Macros(kcal: 35, protein: 2, carbs: 6, fat: 0.4)),
  Food(id: 'caesar_salad', name: 'Chicken Caesar salad', emoji: '🥗', servingLabel: '1 bowl', servingGrams: 300, macros: Macros(kcal: 470, protein: 35, carbs: 18, fat: 29)),
  Food(id: 'sweet_potato', name: 'Sweet potato (baked)', emoji: '🍠', servingLabel: '1 medium', servingGrams: 150, macros: Macros(kcal: 135, protein: 3, carbs: 31, fat: 0.2)),
  Food(id: 'carrots', name: 'Carrot sticks', emoji: '🥕', servingLabel: '1 cup', servingGrams: 120, macros: Macros(kcal: 50, protein: 1.1, carbs: 12, fat: 0.3)),

  // Proteins
  Food(id: 'chicken_breast', name: 'Chicken breast (grilled)', emoji: '🍗', servingLabel: '150 g', servingGrams: 150, macros: Macros(kcal: 248, protein: 46, carbs: 0, fat: 5.4)),
  Food(id: 'salmon', name: 'Salmon fillet (baked)', emoji: '🐟', servingLabel: '150 g', servingGrams: 150, macros: Macros(kcal: 310, protein: 33, carbs: 0, fat: 19)),
  Food(id: 'tuna_can', name: 'Tuna (canned in water)', emoji: '🐟', servingLabel: '1 can', servingGrams: 120, macros: Macros(kcal: 130, protein: 29, carbs: 0, fat: 1)),
  Food(id: 'steak', name: 'Sirloin steak', emoji: '🥩', servingLabel: '200 g', servingGrams: 200, macros: Macros(kcal: 420, protein: 54, carbs: 0, fat: 22)),
  Food(id: 'ground_beef', name: 'Ground beef (90% lean)', emoji: '🥩', servingLabel: '120 g', servingGrams: 120, macros: Macros(kcal: 260, protein: 30, carbs: 0, fat: 15)),
  Food(id: 'tofu', name: 'Tofu (firm)', emoji: '🧊', servingLabel: '150 g', servingGrams: 150, macros: Macros(kcal: 216, protein: 24, carbs: 4, fat: 13)),
  Food(id: 'shrimp', name: 'Shrimp (cooked)', emoji: '🍤', servingLabel: '100 g', servingGrams: 100, macros: Macros(kcal: 99, protein: 24, carbs: 0.2, fat: 0.3)),
  Food(id: 'cottage_cheese', name: 'Cottage cheese', emoji: '🥛', servingLabel: '½ cup', servingGrams: 113, macros: Macros(kcal: 92, protein: 12, carbs: 4, fat: 2.5)),
  Food(id: 'protein_shake', name: 'Whey protein shake', emoji: '🥤', servingLabel: '1 scoop + water', servingGrams: 30, macros: Macros(kcal: 120, protein: 24, carbs: 3, fat: 1.5)),
  Food(id: 'lentils', name: 'Lentils (cooked)', emoji: '🫘', servingLabel: '1 cup', servingGrams: 198, macros: Macros(kcal: 230, protein: 18, carbs: 40, fat: 0.8)),

  // Grains & mains
  Food(id: 'white_rice', name: 'White rice (cooked)', emoji: '🍚', servingLabel: '1 cup', servingGrams: 158, macros: Macros(kcal: 205, protein: 4.3, carbs: 45, fat: 0.4)),
  Food(id: 'brown_rice', name: 'Brown rice (cooked)', emoji: '🍚', servingLabel: '1 cup', servingGrams: 195, macros: Macros(kcal: 216, protein: 5, carbs: 45, fat: 1.8)),
  Food(id: 'quinoa', name: 'Quinoa (cooked)', emoji: '🌾', servingLabel: '1 cup', servingGrams: 185, macros: Macros(kcal: 222, protein: 8, carbs: 39, fat: 3.6)),
  Food(id: 'pasta', name: 'Pasta (cooked)', emoji: '🍝', servingLabel: '1 cup', servingGrams: 140, macros: Macros(kcal: 220, protein: 8, carbs: 43, fat: 1.3)),
  Food(id: 'spaghetti_bolognese', name: 'Spaghetti bolognese', emoji: '🍝', servingLabel: '1 plate', servingGrams: 350, macros: Macros(kcal: 590, protein: 30, carbs: 70, fat: 20)),
  Food(id: 'pizza_slice', name: 'Pizza (margherita)', emoji: '🍕', servingLabel: '1 slice', servingGrams: 107, macros: Macros(kcal: 270, protein: 11, carbs: 33, fat: 10)),
  Food(id: 'burger', name: 'Cheeseburger', emoji: '🍔', servingLabel: '1 burger', servingGrams: 220, macros: Macros(kcal: 550, protein: 30, carbs: 40, fat: 30)),
  Food(id: 'fries', name: 'French fries', emoji: '🍟', servingLabel: 'medium', servingGrams: 117, macros: Macros(kcal: 365, protein: 4, carbs: 48, fat: 17)),
  Food(id: 'burrito', name: 'Chicken burrito', emoji: '🌯', servingLabel: '1 burrito', servingGrams: 350, macros: Macros(kcal: 680, protein: 38, carbs: 78, fat: 22)),
  Food(id: 'tacos', name: 'Beef tacos', emoji: '🌮', servingLabel: '2 tacos', servingGrams: 200, macros: Macros(kcal: 420, protein: 22, carbs: 32, fat: 22)),
  Food(id: 'sushi', name: 'Sushi (salmon roll)', emoji: '🍣', servingLabel: '8 pieces', servingGrams: 220, macros: Macros(kcal: 380, protein: 16, carbs: 58, fat: 9)),
  Food(id: 'ramen', name: 'Ramen', emoji: '🍜', servingLabel: '1 bowl', servingGrams: 500, macros: Macros(kcal: 550, protein: 22, carbs: 70, fat: 20)),
  Food(id: 'curry', name: 'Chicken curry', emoji: '🍛', servingLabel: '1 bowl', servingGrams: 300, macros: Macros(kcal: 450, protein: 32, carbs: 18, fat: 28)),
  Food(id: 'sandwich', name: 'Turkey sandwich', emoji: '🥪', servingLabel: '1 sandwich', servingGrams: 220, macros: Macros(kcal: 380, protein: 26, carbs: 40, fat: 12)),
  Food(id: 'poke_bowl', name: 'Salmon poke bowl', emoji: '🍱', servingLabel: '1 bowl', servingGrams: 420, macros: Macros(kcal: 620, protein: 34, carbs: 72, fat: 20)),
  Food(id: 'bagel', name: 'Bagel', emoji: '🥯', servingLabel: '1 bagel', servingGrams: 100, macros: Macros(kcal: 270, protein: 10, carbs: 53, fat: 1.7)),
  Food(id: 'cream_cheese', name: 'Cream cheese', emoji: '🧀', servingLabel: '1 tbsp', servingGrams: 15, macros: Macros(kcal: 51, protein: 0.9, carbs: 0.8, fat: 5)),
  Food(id: 'cheese', name: 'Cheddar cheese', emoji: '🧀', servingLabel: '1 slice', servingGrams: 28, macros: Macros(kcal: 113, protein: 7, carbs: 0.4, fat: 9.3)),

  // Snacks & sweets
  Food(id: 'almonds', name: 'Almonds', emoji: '🌰', servingLabel: '1 handful', servingGrams: 28, macros: Macros(kcal: 164, protein: 6, carbs: 6, fat: 14)),
  Food(id: 'protein_bar', name: 'Protein bar', emoji: '🍫', servingLabel: '1 bar', servingGrams: 60, macros: Macros(kcal: 220, protein: 20, carbs: 22, fat: 7)),
  Food(id: 'dark_chocolate', name: 'Dark chocolate (70%)', emoji: '🍫', servingLabel: '2 squares', servingGrams: 20, macros: Macros(kcal: 120, protein: 1.6, carbs: 9, fat: 8.5)),
  Food(id: 'hummus', name: 'Hummus', emoji: '🫘', servingLabel: '2 tbsp', servingGrams: 30, macros: Macros(kcal: 70, protein: 2, carbs: 4, fat: 5)),
  Food(id: 'chips', name: 'Potato chips', emoji: '🥔', servingLabel: '1 small bag', servingGrams: 28, macros: Macros(kcal: 152, protein: 2, carbs: 15, fat: 10)),
  Food(id: 'popcorn', name: 'Popcorn (air-popped)', emoji: '🍿', servingLabel: '3 cups', servingGrams: 24, macros: Macros(kcal: 93, protein: 3, carbs: 19, fat: 1)),
  Food(id: 'ice_cream', name: 'Ice cream', emoji: '🍨', servingLabel: '½ cup', servingGrams: 66, macros: Macros(kcal: 137, protein: 2.3, carbs: 16, fat: 7)),
  Food(id: 'cookie', name: 'Chocolate chip cookie', emoji: '🍪', servingLabel: '1 cookie', servingGrams: 30, macros: Macros(kcal: 148, protein: 1.6, carbs: 20, fat: 7)),

  // Drinks
  Food(id: 'coffee_black', name: 'Coffee (black)', emoji: '☕', servingLabel: '1 cup', servingGrams: 240, macros: Macros(kcal: 2, protein: 0.3, carbs: 0, fat: 0)),
  Food(id: 'latte', name: 'Latte', emoji: '☕', servingLabel: 'medium (350 ml)', servingGrams: 350, macros: Macros(kcal: 190, protein: 12, carbs: 18, fat: 7)),
  Food(id: 'milk', name: 'Milk (2%)', emoji: '🥛', servingLabel: '1 cup', servingGrams: 244, macros: Macros(kcal: 122, protein: 8, carbs: 12, fat: 4.8)),
  Food(id: 'milk_splash', name: 'Milk (splash)', emoji: '🥛', servingLabel: '2 tbsp', servingGrams: 30, macros: Macros(kcal: 15, protein: 1, carbs: 1.5, fat: 0.6)),
  Food(id: 'orange_juice', name: 'Orange juice', emoji: '🧃', servingLabel: '1 glass', servingGrams: 250, macros: Macros(kcal: 112, protein: 1.7, carbs: 26, fat: 0.5)),
  Food(id: 'smoothie', name: 'Fruit smoothie', emoji: '🥤', servingLabel: '1 glass', servingGrams: 350, macros: Macros(kcal: 210, protein: 4, carbs: 46, fat: 1.5)),
  Food(id: 'soda', name: 'Cola', emoji: '🥤', servingLabel: '1 can', servingGrams: 355, macros: Macros(kcal: 140, protein: 0, carbs: 39, fat: 0)),
  Food(id: 'beer', name: 'Beer', emoji: '🍺', servingLabel: '1 bottle', servingGrams: 355, macros: Macros(kcal: 153, protein: 1.6, carbs: 13, fat: 0)),
  Food(id: 'wine', name: 'Red wine', emoji: '🍷', servingLabel: '1 glass', servingGrams: 150, macros: Macros(kcal: 125, protein: 0.1, carbs: 3.8, fat: 0)),
  Food(id: 'olive_oil', name: 'Olive oil', emoji: '🫒', servingLabel: '1 tbsp', servingGrams: 14, macros: Macros(kcal: 119, protein: 0, carbs: 0, fat: 13.5)),
];
