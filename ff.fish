# =============================================================================
# ff - Flexible File Finder (Fish Shell Version)
# An interactive file search and navigation tool using fzf.
# Supports dual mode: Find (by filename) and Grep (by content)
# =============================================================================

function ff
    set -l mode "find"
    if test (count $argv) -gt 0
        set mode $argv[1]
    end

    set -l out
    set -l key
    set -l result
    set -l file
    set -l line
    set -l target_dir
    set -l preview_cmd
    set -l grep_base_cmd
    set -l full_reload_cmd
    set -l find_cmd

    # --- Guide message constants ---
    set -l MSG_GREP_GUIDE "Type to search content..."

    # --- FZF UI Options ---
    set -l base_opts '
    --height 60%
    --layout=reverse
    --border
    --info=inline
    --prompt=">"
    --pointer=">"
    --marker="✓"
    --ansi
    --preview-window=right:60%
  '

    # --- 1. Dependency tool configuration ---
    set -l BAT_CMD "cat"
    set -l BAT_OPTS ""

    if command -v batcat >/dev/null 2>&1
        set BAT_CMD "batcat"
        set BAT_OPTS "--style=numbers --color=always"
    else if command -v bat >/dev/null 2>&1
        set BAT_CMD "bat"
        set BAT_OPTS "--style=numbers --color=always"
    end

    set -l USE_FD 0
    if command -v fd >/dev/null 2>&1
        set USE_FD 1
    end

    set -l USE_RG 0
    if command -v rg >/dev/null 2>&1
        set USE_RG 1
    end

    set -l USE_EZA 0
    if command -v eza >/dev/null 2>&1
        set USE_EZA 1
    end

    set -l EDITOR_CMD "$EDITOR"
    if test -z "$EDITOR_CMD"
        set EDITOR_CMD "vi"
    end

    set -l IS_VSCODE 0
    if command -v code >/dev/null 2>&1
        set EDITOR_CMD "code"
        set IS_VSCODE 1
    end

    # Main loop
    while true
        # --- 2. Execute FZF based on current mode ---
        if test "$mode" = "find"
            # [FIND MODE]

            if test $USE_EZA -eq 1
                set preview_cmd "if test -d {}; eza --tree --color=always --level=2 --icons {}; else $BAT_CMD $BAT_OPTS {}; end"
            else if command -v tree >/dev/null 2>&1
                set preview_cmd "if test -d {}; tree -C -L 2 {}; else $BAT_CMD $BAT_OPTS {}; end"
            else
                set preview_cmd "if test -d {}; echo '📂 Directory: {}'; else $BAT_CMD $BAT_OPTS {}; end"
            end

            if test $USE_FD -eq 1
                set find_cmd "fd . --type f --type d --follow --color=never"
            else
                set find_cmd "find . \\( -type d -name '.\\*' \\) -prune -o -print"
            end

            set out (eval $find_cmd 2>/dev/null | \
                env FZF_DEFAULT_OPTS=$base_opts fzf --expect=tab,ctrl-o --cycle -i \
                --prompt="🔍 FIND > " \
                --header='TAB: switch | ENTER: cd | CTRL-O: open' \
                --bind "ctrl-u:preview-up,ctrl-d:preview-down" \
                --preview "$preview_cmd")

        else
            # [GREP MODE]

            if test $USE_RG -eq 1
                set grep_base_cmd "rg --column --line-number --no-heading --color=never --smart-case --null -- {q} | perl -pe 's/\0(\d+):.*/|\1/' || true"
            else
                set grep_base_cmd "grep -Rni --color=never --null -- {q} . | perl -pe 's/\0(\d+):.*/|\1/' || true"
            end

            set full_reload_cmd "if test -z '{q}'; echo '$MSG_GREP_GUIDE'; else $grep_base_cmd; end"

            set out (echo "$MSG_GREP_GUIDE" | \
                env FZF_DEFAULT_OPTS=$base_opts fzf --expect=tab,ctrl-o --delimiter '\\|' --cycle --disabled \
                --prompt="📝 GREP > " \
                --header='TAB: switch | ENTER: cd | CTRL-O: open' \
                --bind "start:reload:$full_reload_cmd" \
                --bind "change:reload:sleep 0.1; $full_reload_cmd" \
                --bind "ctrl-u:preview-up,ctrl-d:preview-down" \
                --preview "if test '{}' = '$MSG_GREP_GUIDE'; echo 'Type to search...'; else
                  set file (echo {} | cut -d\\| -f1);
                  set line (echo {} | cut -d\\| -f2);
                  test -n \"\$file\" && $BAT_CMD $BAT_OPTS --highlight-line \$line \$file;
                end" \
                --preview-window='+{2}-5')
        end

        # --- 3. Parse key input and result ---
        if test -z "$out"
            return
        end

        set key (echo "$out" | head -n 1)
        set result (echo "$out" | sed -n '2p')

        if test "$key" = "tab"
            if test "$mode" = "find"
                set mode "grep"
            else
                set mode "find"
            end
            continue
        end

        if test -z "$result"
            return
        end

        if test "$result" = "$MSG_GREP_GUIDE"
            continue
        end

        # --- 4. Parse result based on mode ---
        if test "$mode" = "grep"
            set file (echo "$result" | cut -d\| -f1)
            set line (echo "$result" | cut -d\| -f2)

            if not test -f "$file"
                echo "⚠️  File not found: $file" >&2
                return
            end
        else
            set file "$result"
            set line ""
        end

        # --- 5. Execute action based on key pressed ---
        if test "$key" = "ctrl-o"
            if test -f "$file"
                if test $IS_VSCODE -eq 1
                    if test -n "$line"
                        code --goto "$file:$line"
                        echo "📄 Opened: $file|$line"
                    else
                        code "$file"
                        echo "📄 Opened: $file"
                    end
                else
                    if test -n "$line"
                        eval $EDITOR_CMD "+$line" "$file"
                        echo "📄 Opened: $file|$line"
                    else
                        eval $EDITOR_CMD "$file"
                        echo "📄 Opened: $file"
                    end
                end
            end
            return
        end

        if test -f "$file"
            set target_dir (dirname "$file")
        else if test -d "$file"
            set target_dir "$file"
        end

        if test -n "$target_dir"; and test -d "$target_dir"
            cd "$target_dir"
            echo "📂 Moved to: "(pwd)
        else
            echo "❌ Invalid path" >&2
        end
        return
    end
end
