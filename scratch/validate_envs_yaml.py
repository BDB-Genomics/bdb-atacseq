import yaml
import sys
import os

def validate_yamls(directory):
    success = True
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".yaml"):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r') as f:
                        yaml.safe_load(f)
                    print(f"[PASS] {filepath}")
                except yaml.YAMLError as exc:
                    print(f"[FAIL] {filepath}: {exc}")
                    success = False
                except Exception as e:
                    print(f"[ERROR] {filepath}: {e}")
                    success = False
    return success

if __name__ == "__main__":
    if validate_yamls("rules/envs"):
        print("\nALL YAML FILES ARE VALID.")
        sys.exit(0)
    else:
        print("\nSOME YAML FILES FAILED VALIDATION.")
        sys.exit(1)
