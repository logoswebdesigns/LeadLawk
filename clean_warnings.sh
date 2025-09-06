#!/bin/bash

echo "🧹 Cleaning up Flutter warnings automatically..."

# 1. Remove unused imports
echo "Removing unused imports..."
dart fix --apply --code=unused_import

# 2. Add const constructors where needed  
echo "Adding const constructors..."
dart fix --apply --code=prefer_const_constructors
dart fix --apply --code=prefer_const_constructors_in_immutables
dart fix --apply --code=prefer_const_literals_to_create_immutables
dart fix --apply --code=prefer_const_declarations

# 3. Fix deprecated member usage
echo "Fixing deprecated APIs..."
dart fix --apply --code=deprecated_member_use

# 4. Remove debug prints from tests
echo "Removing debug prints..."
find test -name "*.dart" -exec sed -i '' 's/print(/\/\/print(/g' {} \;

# 5. Apply all safe fixes
echo "Applying all other safe fixes..."
dart fix --apply

echo "✅ Cleanup complete! Running flutter analyze..."
flutter analyze

echo "📊 Summary:"
flutter analyze 2>&1 | tail -5