 #!/usr/bin/env bash                                                                
#                                                                                  
# fix_exec_bits.sh -- align tracked-file exec bits with the git index
# (run on the HOST, repo root).                                                                    
#                                                                                  
# For every tracked file, set the working-tree mode to match the index:            
#   100644 -> chmod 644   (remove any stray +x -- non-executables)                 
#   100755 -> chmod 755   (keep / restore the genuine executable bit)              
#                                                                                  
# Symlinks (120000) and submodules (160000) are skipped untouched. Only files      
# git already tracks are touched -- never destroys a mode git intends to keep,     
# never touches untracked files. Idempotent: re-running is a no-op.                
set -euo pipefail                                                                  
cd "$(git rev-parse --show-toplevel)" || exit 1                                    
                                                              
fixed=0 repaired_exec=0                                                            
while IFS=$'\t ' read -r mode _ _ path; do                                         
case "$mode" in                                                                  
  100644)                                                                        
    # Tracked as non-executable: strip any stray +x from the working tree.       
    if [[ -f "$path" && -x "$path" ]]; then                                      
      chmod 644 "$path"                                                          
      printf 'strip +x   %s\n' "$path"                                           
      fixed=$((fixed + 1))                                                       
    fi                                                                           
    ;;                                                                           
  100755)                                                                        
    # Tracked as executable: ensure the working tree actually has +x.            
    if [[ -f "$path" && ! -x "$path" ]]; then                                    
      chmod 755 "$path"                                                          
      printf 'restore +x %s\n' "$path"                                           
      repaired_exec=$((repaired_exec + 1))                                       
  fi                                                                           
  ;;                                                                           
esac                                                                             
done < <(git ls-files -s)                                                          
                                                              
printf '\nStripped `+x` from %d file(s); restored `+x` on %d executable(s).\n' "$fixed" "$repaired_exec"                                                            
echo 'Verify: git status --short   (mode-only "modified" entries should be gone)'