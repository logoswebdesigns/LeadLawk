#!/usr/bin/env python3
import os

# Map incorrect icon names to correct ones
ICON_REPLACEMENTS = {
    'Icons.refresh.block': 'Icons.block',
    'Icons.refresh.trending_down': 'Icons.trending_down',
    'Icons.refresh.fiber_new': 'Icons.fiber_new',
    'Icons.refresh.language': 'Icons.language',
    'Icons.refresh.emoji_events': 'Icons.emoji_events',
    'Icons.refresh.verified': 'Icons.verified',
    'Icons.refresh.speed': 'Icons.speed',
    'Icons.refresh.speed_outlined': 'Icons.speed',
    'Icons.refresh.tasks': 'Icons.task_alt',
}

def fix_file(filepath):
    """Fix icon names in a file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        
        for wrong, correct in ICON_REPLACEMENTS.items():
            content = content.replace(wrong, correct)
        
        if content != original:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        return False
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Fix all icon names"""
    fixed_count = 0
    
    for root, dirs, files in os.walk('lib'):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                if fix_file(filepath):
                    print(f"Fixed: {filepath}")
                    fixed_count += 1
    
    for root, dirs, files in os.walk('test'):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                if fix_file(filepath):
                    print(f"Fixed: {filepath}")
                    fixed_count += 1
    
    print(f"\nTotal files fixed: {fixed_count}")

if __name__ == '__main__':
    main()