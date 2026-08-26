import os
import re
import sys

def main():
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    seen_uids = {}
    duplicates = []
    
    uid_pattern = re.compile(r'uid="uid://([a-z0-9]+)"')

    for dirpath, dirnames, filenames in os.walk(root_dir):
        # Skip internal folders
        if '.godot' in dirpath or '.git' in dirpath:
            continue
            
        for filename in filenames:
            filepath = os.path.join(dirpath, filename)
            
            # Check .uid files
            if filename.endswith('.uid'):
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        content = f.read().strip()
                        if content.startswith('uid://'):
                            uid = content
                            if uid in seen_uids:
                                duplicates.append((uid, filepath))
                            else:
                                seen_uids[uid] = filepath
                except Exception as e:
                    print(f"Error reading {filepath}: {e}")
                    
            # Check resource files (.tscn, .tres, .material)
            elif filename.endswith(('.tscn', '.tres', '.material')):
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        first_line = f.readline()
                        match = uid_pattern.search(first_line)
                        if match:
                            uid = 'uid://' + match.group(1)
                            if uid in seen_uids:
                                duplicates.append((uid, filepath))
                            else:
                                seen_uids[uid] = filepath
                except Exception as e:
                    pass

    if not duplicates:
        print("No duplicate UIDs found. If Godot still reports duplicates, try deleting the `.godot` directory.")
        return

    print(f"Found {len(duplicates)} duplicate UIDs:")
    for uid, filepath in duplicates:
        original = seen_uids[uid]
        print(f" - {filepath} (duplicate of {original})")
        
        # Fix the duplicate by removing the UID so Godot regenerates it
        if filepath.endswith('.uid'):
            print(f"   -> Removing duplicate .uid file: {filepath}")
            os.remove(filepath)
        else:
            print(f"   -> Removing UID from resource file: {filepath}")
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Replace uid="..." in the first line
            new_content = re.sub(r'\s*uid="uid://[a-z0-9]+"', '', content, count=1)
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)

    print("Fixes applied. Please restart the Godot editor to regenerate UIDs.")

if __name__ == "__main__":
    main()
