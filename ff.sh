# =============================================================================
# ff - Flexible File Finder
# An interactive file search and navigation tool using fzf.
# Supports dual mode: Find (by filename) and Grep (by content)
# =============================================================================

ff() {
  local mode="${1:-find}"
  local out key result file line target_dir
  local preview_cmd grep_base_cmd full_reload_cmd
  local find_cmd_arr

  # --- Guide message constants ---
  local MSG_GREP_GUIDE="Type to search content..."

  # --- FZF UI Options defined LOCALLY ---
  local base_opts='
    --height 60%
    --layout=reverse
    --border
    --info=inline
    --prompt="❯  "
    --pointer="▶"
    --marker="✓"
    --ansi
    --preview-window=right:60%
  '

  # --- 1. Dependency tool configuration ---
  local BAT_CMD="cat"
  local BAT_OPTS=""
  
  if command -v batcat >/dev/null; then 
    BAT_CMD="batcat"
    BAT_OPTS="--style=numbers --color=always"
  elif command -v bat >/dev/null; then 
    BAT_CMD="bat"
    BAT_OPTS="--style=numbers --color=always"
  fi

  local USE_FD=0; command -v fd >/dev/null && USE_FD=1
  local USE_RG=0; command -v rg >/dev/null && USE_RG=1
  local USE_EZA=0; command -v eza >/dev/null && USE_EZA=1
  
  local EDITOR_CMD="${EDITOR:-vi}"
  local IS_VSCODE=0
  if command -v code >/dev/null; then 
    EDITOR_CMD="code"
    IS_VSCODE=1
  fi

  # Main loop
  while :; do
    # --- 2. Execute FZF based on current mode ---
    if [[ "$mode" == "find" ]]; then
      # [FIND MODE]
      
      if [[ "$USE_EZA" -eq 1 ]]; then
        preview_cmd="if [[ -d {} ]]; then eza --tree --color=always --level=2 --icons {}; else $BAT_CMD $BAT_OPTS {}; fi"
      elif command -v tree >/dev/null; then
        preview_cmd="if [[ -d {} ]]; then tree -C -L 2 {}; else $BAT_CMD $BAT_OPTS {}; fi"
      else
        preview_cmd="if [[ -d {} ]]; then echo '📂 Directory: {}'; else $BAT_CMD $BAT_OPTS {}; fi"
      fi

      if [[ "$USE_FD" -eq 1 ]]; then
        find_cmd_arr=(fd . --type f --type d --follow --color=never)
      else
        find_cmd_arr=(find . -name '.*' -prune -o \( -type f -o -type d \) -print)
      fi

      # Apply options strictly to this command execution
      out=$("${find_cmd_arr[@]}" 2>/dev/null | \
        FZF_DEFAULT_OPTS="$base_opts" fzf --expect=tab,ctrl-o --cycle -i \
        --prompt="🔍 FIND >  " \
        --header=$'TAB: switch | ENTER: cd | CTRL-O: open' \
        --bind "ctrl-u:preview-up,ctrl-d:preview-down" \
        --preview "$preview_cmd")

    else
      # [GREP MODE]
      
      if [[ "$USE_RG" -eq 1 ]]; then
        grep_base_cmd="rg --column --line-number --no-heading --color=never --smart-case --null -- {q} | perl -pe 's/\0(\d+):.*/|\1/' || true"
      else
        grep_base_cmd="grep -Rni --color=never --null -- {q} . | perl -pe 's/\0(\d+):.*/|\1/' || true"
      fi
      
      full_reload_cmd="if [[ -z {q} ]]; then echo '$MSG_GREP_GUIDE'; else $grep_base_cmd; fi"

      # Apply options strictly to this command execution
      out=$(echo "$MSG_GREP_GUIDE" | \
        FZF_DEFAULT_OPTS="$base_opts" fzf --expect=tab,ctrl-o --delimiter '\|' --cycle --disabled \
        --prompt="📝 GREP >  " \
        --header=$'TAB: switch | ENTER: cd | CTRL-O: open' \
        --bind "start:reload:$full_reload_cmd" \
        --bind "change:reload:sleep 0.1; $full_reload_cmd" \
        --bind "ctrl-u:preview-up,ctrl-d:preview-down" \
        --preview "if [[ {} == '$MSG_GREP_GUIDE' ]]; then echo 'Type to search...'; else 
          file=\$(echo {} | cut -d\| -f1); 
          line=\$(echo {} | cut -d\| -f2); 
          [ -n \"\$file\" ] && $BAT_CMD $BAT_OPTS --highlight-line \$line \$file; 
        fi" \
        --preview-window=+{2}-5)
    fi

    # --- 3. Parse key input and result ---
    [[ -z "$out" ]] && return

    key=$(head -n 1 <<< "$out")
    result=$(sed -n '2p' <<< "$out")

    if [[ "$key" == "tab" ]]; then
      [[ "$mode" == "find" ]] && mode="grep" || mode="find"
      continue
    fi

    [[ -z "$result" ]] && return
    [[ "$result" == "$MSG_GREP_GUIDE" ]] && continue

    # --- 4. Parse result based on mode ---
    if [[ "$mode" == "grep" ]]; then
      file=$(echo "$result" | cut -d\| -f1)
      line=$(echo "$result" | cut -d\| -f2)
      
      if [[ ! -f "$file" ]]; then
        echo "⚠️  File not found: $file" >&2
        return
      fi
    else
      file="$result"
      line=""
    fi

    # --- 5. Execute action based on key pressed ---
    if [[ "$key" == "ctrl-o" ]]; then
      if [[ -f "$file" ]]; then
        if [[ "$IS_VSCODE" -eq 1 ]]; then
            if [[ -n "$line" ]]; then 
              code --goto "$file:$line"
              echo "📄 Opened: $file|$line"
            else 
              code "$file"
              echo "📄 Opened: $file"
            fi
        else
          if [[ -n "$line" ]]; then 
            $EDITOR_CMD "+$line" "$file"
            echo "📄 Opened: $file|$line"
          else 
            $EDITOR_CMD "$file"
            echo "📄 Opened: $file"
          fi
        fi
      fi
      return
    fi

    if [[ -f "$file" ]]; then 
        target_dir="$(dirname "$file")"
    elif [[ -d "$file" ]]; then 
        target_dir="$file"
    fi

    if [[ -n "$target_dir" && -d "$target_dir" ]]; then
      cd "$target_dir" || return
      echo "📂 Moved to: $(pwd)"
    else
      echo "❌ Invalid path" >&2
    fi
    return
  done
}