import '../db/models.dart';
import 'food_catalog.dart';

/// A ready-made meal built from catalog foods, so Meals is useful on day one.
class PresetMeal {
  const PresetMeal(this.name, this.emoji, this.parts);

  final String name;
  final String emoji;

  /// (catalog food name, servings)
  final List<(String, double)> parts;

  /// Resolves each part against [catalog]; parts it can't find are skipped.
  List<MealItem> items(FoodCatalog catalog) => [
        for (final (food, qty) in parts)
          if (catalog.byName(food) case final f?) f.toMealItem(qty),
      ];

  Totals totals(FoodCatalog catalog) => sumMealItems(items(catalog));
}

const List<PresetMeal> kPresetMeals = [
  PresetMeal('Dal Chawal', '🍛', [
    ('Steamed rice', 1),
    ('Dal tadka', 1),
    ('Green salad', 1),
  ]),
  PresetMeal('Roti Sabzi', '🫓', [
    ('Roti', 2),
    ('Mixed veg curry', 1),
    ('Curd (dahi)', 1),
  ]),
  PresetMeal('Paneer & Roti', '🧀', [
    ('Roti', 2),
    ('Palak paneer', 1),
    ('Green salad', 1),
  ]),
  PresetMeal('Idli Sambar', '🍙', [
    ('Idli', 3),
    ('Sambar', 1),
    ('Coconut chutney', 1),
  ]),
  PresetMeal('Dosa & Sambar', '🥞', [
    ('Plain dosa', 2),
    ('Sambar', 1),
    ('Coconut chutney', 1),
  ]),
  PresetMeal('Poha & Chai', '🥣', [
    ('Poha', 1),
    ('Chai (with milk & sugar)', 1),
  ]),
  PresetMeal('Oats & Milk Bowl', '🥣', [
    ('Oats (dry)', 1),
    ('Milk (whole)', 1),
    ('Banana', 1),
    ('Almonds', 1),
  ]),
  PresetMeal('Egg Toast Breakfast', '🍳', [
    ('Scrambled eggs', 1),
    ('Whole wheat bread', 2),
    ('Banana', 1),
  ]),
  PresetMeal('Peanut Butter Toast', '🥜', [
    ('Whole wheat bread', 2),
    ('Peanut butter', 1),
    ('Banana', 1),
  ]),
  PresetMeal('Chicken & Rice', '🍗', [
    ('Chicken breast (grilled)', 1.5),
    ('Steamed rice', 1),
    ('Broccoli (cooked)', 1),
  ]),
  PresetMeal('Rice & Fish Curry', '🐟', [
    ('Steamed rice', 1),
    ('Fish curry', 1),
    ('Green salad', 1),
  ]),
  PresetMeal('Biryani & Raita', '🍛', [
    ('Chicken biryani', 1),
    ('Raita', 1),
  ]),
  PresetMeal('Khichdi & Curd', '🍲', [
    ('Khichdi', 1),
    ('Curd (dahi)', 1),
    ('Papad (roasted)', 1),
  ]),
  PresetMeal('Moong Chilla Plate', '🥞', [
    ('Moong dal chilla', 2),
    ('Green chutney', 1),
    ('Curd (dahi)', 1),
  ]),
  PresetMeal('Greek Yogurt Bowl', '🫐', [
    ('Greek yogurt', 1),
    ('Blueberries', 0.5),
    ('Almonds', 1),
    ('Honey', 1),
  ]),
  PresetMeal('Protein Shake', '🥤', [
    ('Whey protein', 1),
    ('Milk (toned)', 1),
    ('Banana', 1),
  ]),
  PresetMeal('Tea Time', '🍵', [
    ('Chai (with milk & sugar)', 1),
    ('Marie biscuit', 4),
  ]),
  PresetMeal('Fruit Bowl', '🍎', [
    ('Apple', 1),
    ('Banana', 1),
    ('Papaya', 1),
  ]),

  // --- Regional thalis & combos
  PresetMeal('North Indian Thali', '🍛', [
    ('Roti', 2),
    ('Dal tadka', 1),
    ('Matar paneer', 1),
    ('Jeera rice', 0.5),
    ('Raita', 1),
    ('Green salad', 1),
  ]),
  PresetMeal('Rajma Chawal & Raita', '🫘', [
    ('Rajma chawal', 1),
    ('Raita', 1),
    ('Kachumber salad', 1),
  ]),
  PresetMeal('Sarson Saag & Makki Roti', '🫓', [
    ('Sarson ka saag', 1),
    ('Makki di roti', 2),
    ('Butter', 1),
    ('Chaas / buttermilk', 1),
  ]),
  PresetMeal('Chole Bhature Combo', '🍛', [
    ('Chole bhature', 1),
    ('Pickle (achar)', 1),
    ('Sweet lassi', 1),
  ]),
  PresetMeal('Kulcha & Chole', '🫓', [
    ('Kulcha', 2),
    ('Chole / chana masala', 1),
    ('Raita', 1),
  ]),
  PresetMeal('Rajasthani Thali', '🍛', [
    ('Bajra roti', 2),
    ('Gatte ki sabzi', 1),
    ('Ker sangri', 1),
    ('Panchmel dal', 1),
    ('Curd (dahi)', 1),
  ]),
  PresetMeal('Gujarati Thali', '🍱', [
    ('Roti', 2),
    ('Gujarati dal', 1),
    ('Undhiyu', 1),
    ('Steamed rice', 1),
    ('Gujarati kadhi', 1),
    ('Papad (roasted)', 1),
  ]),
  PresetMeal('Gujarati Farsan Plate', '🧆', [
    ('Dhokla', 1.5),
    ('Khandvi', 1),
    ('Green chutney', 1),
    ('Chai (with milk & sugar)', 1),
  ]),
  PresetMeal('Maharashtrian Thali', '🍱', [
    ('Jowar roti', 2),
    ('Pithla', 1),
    ('Usal', 1),
    ('Steamed rice', 1),
    ('Aamti', 1),
  ]),
  PresetMeal('South Indian Meals', '🍛', [
    ('Steamed rice', 1.5),
    ('Sambar', 1),
    ('Rasam', 1),
    ('Beans poriyal', 1),
    ('Curd (dahi)', 1),
    ('Papad (fried)', 1),
  ]),
  PresetMeal('Kerala Meals', '🍛', [
    ('Steamed rice', 1.5),
    ('Kerala fish curry', 1),
    ('Thoran', 1),
    ('Avial', 1),
    ('Papad (fried)', 1),
  ]),
  PresetMeal('Andhra Meals', '🍛', [
    ('Steamed rice', 1.5),
    ('Dal (toor / arhar)', 1),
    ('Andhra chicken fry', 1),
    ('Rasam', 1),
    ('Curd (dahi)', 1),
  ]),
  PresetMeal('Bengali Lunch', '🍱', [
    ('Steamed rice', 1.5),
    ('Cholar dal', 1),
    ('Machher jhol', 1),
    ('Aloo posto', 1),
    ('Begun bhaja', 1),
    ('Mishti doi', 1),
  ]),
  PresetMeal('Bengali Breakfast', '🫓', [
    ('Luchi', 1.5),
    ('Dum aloo', 1),
    ('Sandesh', 1),
    ('Chai (with milk & sugar)', 1),
  ]),
  PresetMeal('Hyderabadi Biryani Meal', '🍛', [
    ('Chicken biryani', 1),
    ('Raita', 1),
    ('Kachumber salad', 1),
  ]),
  PresetMeal('Butter Chicken & Naan', '🍗', [
    ('Butter chicken', 1),
    ('Naan', 2),
    ('Kachumber salad', 1),
  ]),
  PresetMeal('Chicken Curry & Roti', '🍗', [
    ('Roti', 2),
    ('Chicken curry', 1),
    ('Green salad', 1),
    ('Curd (dahi)', 1),
  ]),
  PresetMeal('Mutton Rogan Josh Meal', '🍖', [
    ('Steamed rice', 1),
    ('Mutton rogan josh', 1),
    ('Kachumber salad', 1),
  ]),
  PresetMeal('Egg Curry & Roti', '🥚', [
    ('Roti', 2),
    ('Egg curry', 1),
    ('Green salad', 1),
  ]),
  PresetMeal('Fish Fry Meal', '🐟', [
    ('Fish fry', 1),
    ('Steamed rice', 1),
    ('Dal tadka', 1),
    ('Kachumber salad', 1),
  ]),

  // --- Breakfast combos
  PresetMeal('Dosa Breakfast', '🥞', [
    ('Masala dosa', 1),
    ('Sambar', 1),
    ('Coconut chutney', 1),
    ('Filter coffee', 1),
  ]),
  PresetMeal('Idli Vada Combo', '🍙', [
    ('Idli', 2),
    ('Medu vada', 1),
    ('Sambar', 1),
    ('Coconut chutney', 1),
  ]),
  PresetMeal('Pongal Breakfast', '🥣', [
    ('Ven pongal', 1),
    ('Sambar', 1),
    ('Medu vada', 1),
    ('Coconut chutney', 1),
    ('Filter coffee', 1),
  ]),
  PresetMeal('Puttu & Kadala Curry', '🍚', [
    ('Puttu', 1.5),
    ('Kala chana curry', 1),
    ('Banana', 1),
  ]),
  PresetMeal('Aloo Paratha & Curd', '🫓', [
    ('Aloo paratha', 2),
    ('Curd (dahi)', 1),
    ('Pickle (achar)', 1),
    ('Chai (with milk & sugar)', 1),
  ]),
  PresetMeal('Bread Omelette & Chai', '🍳', [
    ('Bread omelette', 1),
    ('Chai (with milk & sugar)', 1),
  ]),
  PresetMeal('Upma & Coffee', '🥣', [
    ('Upma', 1),
    ('Filter coffee', 1),
    ('Banana', 1),
  ]),
  PresetMeal('Indori Poha Jalebi', '🥣', [
    ('Poha', 1),
    ('Jalebi', 2),
    ('Chai (with milk & sugar)', 1),
  ]),
  PresetMeal('Besan Chilla Plate', '🥞', [
    ('Besan chilla', 2),
    ('Green chutney', 1),
    ('Curd (dahi)', 1),
  ]),
  PresetMeal('Cornflakes & Milk', '🥣', [
    ('Corn flakes', 1.5),
    ('Milk (toned)', 1),
    ('Banana', 1),
  ]),
  PresetMeal('Muesli & Curd', '🥣', [
    ('Muesli', 1),
    ('Curd (dahi)', 1.5),
    ('Honey', 1),
  ]),

  // --- Gym & high protein
  PresetMeal('Gym Chicken Rice Bowl', '💪', [
    ('Chicken breast (boiled)', 1.5),
    ('White rice (cooked, 100 g)', 1.5),
    ('Broccoli (cooked)', 1),
    ('Olive oil', 0.5),
  ]),
  PresetMeal('Egg White Breakfast', '🍳', [
    ('Egg white omelette', 1),
    ('Whole wheat bread', 2),
    ('Banana', 1),
  ]),
  PresetMeal('Post-Workout Recovery', '💪', [
    ('Whey protein', 1),
    ('Banana', 1),
    ('Dates (khajoor)', 2),
  ]),
  PresetMeal('Soya Chunks & Roti', '🫘', [
    ('Soya chunks curry', 1),
    ('Roti', 2),
    ('Cucumber', 1),
  ]),
  PresetMeal('Paneer Bhurji & Roti', '🧀', [
    ('Paneer bhurji', 1),
    ('Roti', 2),
    ('Green salad', 1),
  ]),
  PresetMeal('High-Protein Dal Lunch', '🍲', [
    ('Moong dal', 1),
    ('Soya chunks (boiled)', 1),
    ('Roti', 2),
    ('Curd (dahi)', 1),
  ]),
  PresetMeal('Oats & Chia Bowl', '🥣', [
    ('Oats porridge (with milk)', 1),
    ('Chia seeds', 1),
    ('Almonds', 1),
    ('Blueberries', 0.5),
  ]),
  PresetMeal('Tuna Salad Bowl', '🥗', [
    ('Tuna (canned in water)', 1),
    ('Green salad', 1),
    ('Olive oil', 0.5),
    ('Whole wheat bread', 1),
  ]),
  PresetMeal('Sweet Potato & Chicken', '🍠', [
    ('Sweet potato (boiled)', 2),
    ('Chicken breast (boiled)', 1.5),
    ('Cucumber', 1),
  ]),

  // --- Office lunch & light dinners
  PresetMeal('Office Tiffin', '🍱', [
    ('Roti', 3),
    ('Mixed veg curry', 1),
    ('Dal tadka', 1),
    ('Curd (dahi)', 1),
  ]),
  PresetMeal('Canteen Thali', '🍛', [
    ('Roti', 3),
    ('Dal tadka', 1),
    ('Aloo gobi', 1),
    ('Steamed rice', 1),
    ('Papad (roasted)', 1),
  ]),
  PresetMeal('Light Office Lunch', '🥪', [
    ('Veg sandwich (grilled)', 1),
    ('Apple', 1),
    ('Green tea', 1),
  ]),
  PresetMeal('Khichdi & Kadhi', '🍲', [
    ('Khichdi', 1),
    ('Gujarati kadhi', 1),
    ('Papad (roasted)', 1),
  ]),
  PresetMeal('Light Moong Dinner', '🍲', [
    ('Moong dal', 1),
    ('Roti', 2),
    ('Lauki sabzi', 1),
  ]),
  PresetMeal('Soup & Salad', '🥗', [
    ('Tomato soup', 1),
    ('Green salad', 1),
    ('Whole wheat bread', 1),
  ]),
  PresetMeal('Pasta Night', '🍝', [
    ('Pasta in tomato sauce', 1),
    ('Garlic bread', 1),
    ('Green salad', 1),
  ]),

  // --- Snacks & street food
  PresetMeal('Chai & Samosa', '🥟', [
    ('Samosa', 1),
    ('Chai (with milk & sugar)', 1),
    ('Green chutney', 1),
  ]),
  PresetMeal('Chai & Pakora', '🧆', [
    ('Pakora', 1),
    ('Chai (with milk & sugar)', 1),
    ('Green chutney', 1),
  ]),
  PresetMeal('Chaat Platter', '🥗', [
    ('Pani puri', 1),
    ('Dahi puri', 1),
    ('Sev puri', 1),
  ]),
  PresetMeal('Vada Pav & Chai', '🍔', [
    ('Vada pav', 1),
    ('Chai (with milk & sugar)', 1),
  ]),
  PresetMeal('Pav Bhaji Dinner', '🍛', [
    ('Pav bhaji', 1),
    ('Kachumber salad', 1),
    ('Chaas / buttermilk', 1),
  ]),
  PresetMeal('Maggi & Egg', '🍜', [
    ('Maggi noodles', 1),
    ('Egg (boiled)', 1),
  ]),
  PresetMeal('Momos & Soup', '🥟', [
    ('Momos (veg)', 1),
    ('Schezwan sauce', 1),
    ('Hot & sour soup', 1),
  ]),
  PresetMeal('Fried Rice & Chilli Paneer', '🥡', [
    ('Veg fried rice', 1),
    ('Chilli paneer', 1),
  ]),

  // --- Fast-food combos
  PresetMeal('McAloo Tikki Combo', '🍔', [
    ('McAloo Tikki burger', 1),
    ('French fries (small)', 1),
    ('Coca-Cola (small bottle)', 1),
  ]),
  PresetMeal('McSpicy Chicken Combo', '🍔', [
    ('McSpicy Chicken burger', 1),
    ('French fries (small)', 1),
    ('Coca-Cola (small bottle)', 1),
  ]),
  PresetMeal('KFC Zinger Combo', '🍗', [
    ('KFC Zinger burger', 1),
    ('French fries (small)', 1),
    ('Cola', 1),
  ]),
  PresetMeal('Dominos Pizza Meal', '🍕', [
    ('Pizza (veg loaded, regular)', 3),
    ('Garlic bread', 1),
    ('Cola', 1),
  ]),
  PresetMeal('Subway Chicken Combo', '🥪', [
    ('Subway chicken sub (6")', 1),
    ('Subway cookie', 1),
    ('Cola', 1),
  ]),
  PresetMeal('Burger & Fries', '🍟', [
    ('Cheeseburger', 1),
    ('French fries', 1),
    ('Cola', 1),
  ]),
  PresetMeal('Starbucks Coffee & Bite', '☕', [
    ('Latte', 1),
    ('Chocolate croissant', 1),
  ]),
];
