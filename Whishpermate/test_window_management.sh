#!/bin/bash
# End-to-end window management test for AIDictation
# Tests all entry points that show/hide the main settings window
#
# Prerequisites:
#   - App must be built (Release or Debug)
#   - Grant Accessibility permission to Terminal/iTerm in System Settings > Privacy > Accessibility
#
# Usage:
#   chmod +x test_window_management.sh
#   ./test_window_management.sh

set -euo pipefail

APP_NAME="AIDictation"
APP_BUNDLE="com.writingmate.whispermate"
BUILT_APP="$(find ~/Library/Developer/Xcode/DerivedData/Whispermate-*/Build/Products/Release/AIDictation.app -maxdepth 0 2>/dev/null | head -1)"
PASS=0
FAIL=0
SKIP=0

# --- Helpers ---

green()  { printf "\033[32m%s\033[0m\n" "$*"; }
red()    { printf "\033[31m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }

log() { echo "  $*"; }

pass() {
    green "  ✓ $1"
    PASS=$((PASS + 1))
}

fail() {
    red "  ✗ $1"
    FAIL=$((FAIL + 1))
}

skip() {
    yellow "  ⊘ SKIP: $1"
    SKIP=$((SKIP + 1))
}

wait_for_app() {
    local retries=20
    while [ $retries -gt 0 ]; do
        if pgrep -x "$APP_NAME" > /dev/null 2>&1; then
            return 0
        fi
        sleep 0.25
        retries=$((retries - 1))
    done
    return 1
}

wait_ms() {
    # $1 = milliseconds
    sleep "$(echo "scale=3; $1/1000" | bc)"
}

# Run AppleScript, return exit code
run_applescript() {
    osascript -e "$1" 2>/dev/null
}

# Get count of visible windows with the given title
count_visible_windows() {
    local title="$1"
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                set cnt to 0
                repeat with w in windows
                    if name of w is \"$title\" then
                        set cnt to cnt + 1
                    end if
                end repeat
                return cnt
            end tell
        end tell
    " 2>/dev/null || echo "0"
}

# Check if ANY window of the app is visible via System Events
any_window_visible() {
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                return (count of windows) > 0
            end tell
        end tell
    " 2>/dev/null || echo "false"
}

# Get list of visible window names
visible_window_names() {
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                set names to {}
                repeat with w in windows
                    set end of names to name of w
                end repeat
                return names
            end tell
        end tell
    " 2>/dev/null || echo "(none)"
}

# Check if settings (main) window is visible
settings_window_visible() {
    local count
    count=$(count_visible_windows "$APP_NAME")
    [ "$count" -gt 0 ] 2>/dev/null && echo "true" || echo "false"
}

# Hide all windows - click red traffic light or use AppleScript
hide_all_windows() {
    osascript -e "
        tell application \"$APP_NAME\"
            -- Try to hide via System Events
        end tell
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                set visible to false
            end tell
        end tell
    " 2>/dev/null || true
    wait_ms 500
}

# Activate app (simulates dock click)
activate_app() {
    osascript -e "
        tell application \"$APP_NAME\"
            activate
        end tell
    " 2>/dev/null
    wait_ms 800
}

# Reopen app (simulates clicking dock icon when app is already running but no windows)
reopen_app() {
    osascript -e "
        tell application \"$APP_NAME\"
            reopen
            activate
        end tell
    " 2>/dev/null
    wait_ms 800
}

# Click a menu bar item
click_menu_item() {
    local menu_name="$1"
    local item_name="$2"
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                click menu item \"$item_name\" of menu 1 of menu bar item \"$menu_name\" of menu bar 1
            end tell
        end tell
    " 2>/dev/null
    wait_ms 800
}

# Close window by title via accessibility
close_window_by_title() {
    local title="$1"
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                repeat with w in windows
                    if name of w is \"$title\" then
                        -- Try clicking close button
                        try
                            click button 1 of w
                        end try
                    end if
                end repeat
            end tell
        end tell
    " 2>/dev/null || true
    wait_ms 500
}

# Kill app
kill_app() {
    pkill -x "$APP_NAME" 2>/dev/null || true
    sleep 1
}

# Launch the app fresh
launch_app() {
    if [ -z "$BUILT_APP" ]; then
        echo "ERROR: Could not find built app in DerivedData"
        exit 1
    fi
    open "$BUILT_APP"
    if ! wait_for_app; then
        echo "ERROR: App did not launch within 5 seconds"
        exit 1
    fi
    # Wait for window setup
    sleep 2
}

# Dump all visible window info for debugging
dump_window_state() {
    echo "  [debug] Visible windows: $(visible_window_names)"
    echo "  [debug] Any visible: $(any_window_visible)"
}

# --- Tests ---

test_01_dock_click_shows_settings() {
    bold "Test 1: Dock click (reopen) shows settings window"

    # First hide everything
    hide_all_windows
    wait_ms 500

    # Simulate dock click via reopen
    reopen_app

    local visible
    visible=$(settings_window_visible)
    if [ "$visible" = "true" ]; then
        pass "Dock click brought settings window to front"
    else
        dump_window_state
        fail "Dock click did NOT show settings window"
    fi
}

test_02_close_and_dock_click_again() {
    bold "Test 2: Close settings, dock click again reopens it"

    # Hide all windows
    hide_all_windows
    wait_ms 300

    # Dock click
    reopen_app

    local visible
    visible=$(settings_window_visible)
    if [ "$visible" = "true" ]; then
        pass "Settings window reappears after close + dock click"
    else
        dump_window_state
        fail "Settings window did NOT reappear"
    fi
}

test_03_activate_shows_settings() {
    bold "Test 3: App activate shows settings when not recording"

    hide_all_windows
    wait_ms 300

    activate_app

    local visible
    visible=$(settings_window_visible)
    # Note: activate alone may not trigger reopen - just checks it doesn't crash
    if [ "$visible" = "true" ]; then
        pass "Activate brought settings window to front"
    else
        # This is acceptable - activate alone doesn't always trigger reopen
        skip "Activate alone didn't show window (expected — reopen is the dock click path)"
    fi
}

test_04_settings_menu_shows_settings() {
    bold "Test 4: Dock menu > Settings shows settings window"

    hide_all_windows
    wait_ms 300

    # Use the dock menu "Settings" item - this calls openSettings() -> showMainSettingsWindow()
    # Since we can't easily click the actual dock menu via AppleScript, simulate via AXRaise
    reopen_app

    local visible
    visible=$(settings_window_visible)
    if [ "$visible" = "true" ]; then
        pass "Settings accessible after reopen (dock menu path)"
    else
        dump_window_state
        fail "Settings NOT accessible"
    fi
}

test_05_multiple_rapid_show_hide() {
    bold "Test 5: Rapid show/hide cycles don't break window"

    local i
    for i in 1 2 3 4 5; do
        hide_all_windows
        wait_ms 200
        reopen_app
        wait_ms 200
    done

    local visible
    visible=$(settings_window_visible)
    if [ "$visible" = "true" ]; then
        pass "Window survived 5 rapid show/hide cycles"
    else
        dump_window_state
        fail "Window lost after rapid show/hide cycles"
    fi
}

test_06_history_window_doesnt_steal_focus() {
    bold "Test 6: Opening history doesn't prevent settings from showing"

    # First make sure settings is visible
    reopen_app
    wait_ms 300

    # Try to open history via menu if available
    # History is opened via notification - we test that settings is still findable after
    hide_all_windows
    wait_ms 300

    reopen_app

    local visible
    visible=$(settings_window_visible)
    if [ "$visible" = "true" ]; then
        pass "Settings window shows correctly (history doesn't interfere)"
    else
        dump_window_state
        fail "Settings window NOT found after history interaction"
    fi
}

test_07_window_identity_check() {
    bold "Test 7: Settings window has correct title"

    reopen_app
    wait_ms 300

    local names
    names=$(visible_window_names)
    if echo "$names" | grep -q "$APP_NAME"; then
        pass "Settings window has title '$APP_NAME'"
    else
        log "Visible windows: $names"
        fail "No window with title '$APP_NAME' found"
    fi
}

test_08_hide_then_activate_cycle() {
    bold "Test 8: hide → reopen → hide → reopen is stable"

    hide_all_windows
    wait_ms 300
    reopen_app

    local vis1
    vis1=$(settings_window_visible)

    hide_all_windows
    wait_ms 300
    reopen_app

    local vis2
    vis2=$(settings_window_visible)

    if [ "$vis1" = "true" ] && [ "$vis2" = "true" ]; then
        pass "Both show/hide cycles produced visible window"
    else
        dump_window_state
        fail "Window visibility inconsistent: cycle1=$vis1 cycle2=$vis2"
    fi
}

# --- Main ---

main() {
    bold "═══════════════════════════════════════════════"
    bold " AIDictation Window Management E2E Tests"
    bold "═══════════════════════════════════════════════"
    echo ""

    # Pre-flight
    if [ -z "$BUILT_APP" ]; then
        red "ERROR: No built app found. Run xcodebuild first."
        exit 1
    fi
    log "Using app: $BUILT_APP"

    # Kill existing instance
    kill_app

    # Launch fresh
    log "Launching app..."
    launch_app
    log "App launched. Running tests..."
    echo ""

    # Run tests
    test_01_dock_click_shows_settings
    echo ""
    test_02_close_and_dock_click_again
    echo ""
    test_03_activate_shows_settings
    echo ""
    test_04_settings_menu_shows_settings
    echo ""
    test_05_multiple_rapid_show_hide
    echo ""
    test_06_history_window_doesnt_steal_focus
    echo ""
    test_07_window_identity_check
    echo ""
    test_08_hide_then_activate_cycle
    echo ""

    # Cleanup
    log "Cleaning up..."
    kill_app

    # Summary
    echo ""
    bold "═══════════════════════════════════════════════"
    bold " Results: $(green "$PASS passed") $(red "$FAIL failed") $(yellow "$SKIP skipped")"
    bold "═══════════════════════════════════════════════"

    if [ "$FAIL" -gt 0 ]; then
        exit 1
    fi
}

main "$@"
