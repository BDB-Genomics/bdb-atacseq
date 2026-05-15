import os
import re

def reformat_smk(filepath):
    with open(filepath, 'r') as f:
        lines = f.readlines()

    directives = {
        'log': None,
        'conda': None,
        'threads': None,
        'message': None
    }
    
    new_lines = []
    current_directive = None
    directive_buffer = []
    
    # 1. Extract directives and remove them from original content
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        
        # Check if line starts a directive
        match = re.match(r'^    (log|conda|threads|message):\s*(.*)', line)
        if match:
            current_directive = match.group(1)
            rest = match.group(2).strip()
            if rest:
                directives[current_directive] = rest
                current_directive = None
            else:
                # Multi-line directive
                directive_buffer = []
                i += 1
                while i < len(lines) and lines[i].startswith('        '):
                    directive_buffer.append(lines[i].strip())
                    i += 1
                directives[current_directive] = " ".join(directive_buffer)
                current_directive = None
                continue # Already incremented i
        else:
            new_lines.append(line)
        i += 1

    # 2. Find the end of resources block to insert directives
    insert_idx = -1
    for i, line in enumerate(new_lines):
        if re.match(r'^    resources:', line):
            # Find the end of this block
            j = i + 1
            while j < len(new_lines) and (new_lines[j].startswith('        ') or new_lines[j].strip() == ''):
                j += 1
            insert_idx = j
            break
    
    if insert_idx == -1:
        # If no resources, find end of params or output
        for target in ['params:', 'output:', 'input:']:
            for i, line in enumerate(new_lines):
                if re.match(f'^    {target}', line):
                    j = i + 1
                    while j < len(new_lines) and (new_lines[j].startswith('        ') or new_lines[j].strip() == ''):
                        j += 1
                    insert_idx = j
                    break
            if insert_idx != -1: break

    # 3. Reconstruct the file
    if insert_idx != -1:
        # Prepare the block
        block = []
        if directives['log']: block.append(f"    log: {directives['log']}\n")
        if directives['conda']: block.append(f"    conda: {directives['conda']}\n")
        if directives['threads']: block.append(f"    threads: {directives['threads']}\n")
        if directives['message']: block.append(f"    message: {directives['message']}\n")
        
        # Clean up empty lines around insert point
        while insert_idx < len(new_lines) and new_lines[insert_idx].strip() == '':
            new_lines.pop(insert_idx)
        
        new_lines.insert(insert_idx, "\n")
        for k, b_line in enumerate(block):
            new_lines.insert(insert_idx + 1 + k, b_line)
        new_lines.insert(insert_idx + 1 + len(block), "\n")

    # Final cleanup of multiple empty lines
    final_content = "".join(new_lines)
    final_content = re.sub(r'\n{3,}', '\n\n', final_content)
    
    with open(filepath, 'w') as f:
        f.write(final_content)

if __name__ == "__main__":
    for f in os.listdir("rules"):
        if f.endswith(".smk"):
            print(f"Reformatting rules/{f}...")
            reformat_smk(os.path.join("rules", f))
