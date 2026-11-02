property authTabId : missing value
property authWindowRef : missing value

on run argv
    set deviceURL to item 1 of argv
    set deviceCode to item 2 of argv
    set accountEmail to item 3 of argv
    if deviceURL does not start with "https://login.microsoft.com/device" and deviceURL does not start with "https://microsoft.com/devicelogin" then error "Unexpected device sign-in URL"

    set authTabId to missing value
    set authWindowRef to missing value
    set stepName to "opening Chrome"
    try
        tell application "Google Chrome"
            set newWindow to make new window
            set URL of active tab of newWindow to deviceURL
            set authTabId to id of active tab of newWindow
            set authWindowRef to newWindow
            activate
        end tell
        my focusAuthWindow(my authWin())

        set stepName to "waiting for the device code page"
        set ready to false
        repeat 40 times
            delay 0.5
            if my authURL() contains "login.microsoftonline.com/common/oauth2/deviceauth" then
                set ready to true
                exit repeat
            end if
        end repeat
        if ready is false then error "Chrome did not show the Microsoft device code page"

        set stepName to "entering the device code"
        delay 1
        if my focusAuthWindow(my authWin()) is false then error "Could not bring the Microsoft sign-in window to the front"
        tell application "System Events"
            keystroke deviceCode
            key code 36
        end tell

        set stepName to "picking the account"
        set accountChosen to false
        set chooseAttempts to 0
        set ticksSinceChosen to 0
        repeat 80 times
            delay 0.5
            set currentURL to my authURL()
            if currentURL contains "/appverify" then exit repeat
            if accountChosen and currentURL does not contain "/deviceauth" then exit repeat
            -- Chrome sometimes ignores a press on the account tile; if the page has not moved on, try again,
            -- alternating between keyboard/accessibility presses and a real mouse click.
            if accountChosen then
                set ticksSinceChosen to ticksSinceChosen + 1
                if ticksSinceChosen ≥ 8 then set accountChosen to false
            end if
            if accountChosen is false then
                set chooseAttempts to chooseAttempts + 1
                set ticksSinceChosen to 0
                set useMouse to (chooseAttempts mod 2 is 0)
                if useMouse is false and my pressFocusedNamed(accountEmail, my authWin()) then
                    set accountChosen to true
                else
                    set scanResult to my chooseAccount(accountEmail, my authWin(), useMouse)
                    if scanResult is "chosen" then
                        set accountChosen to true
                    else if scanResult is "another" then
                        delay 1
                    end if
                end if
            end if
        end repeat
        if currentURL contains "/deviceauth" then error "Could not get past the Microsoft account page after " & chooseAttempts & " tries"

        set stepName to "confirming the sign-in"
        set ticksSincePress to 99
        repeat 120 times
            delay 0.5
            set currentURL to my authURL()
            if currentURL contains "/appverify" then
                my closeAuthTab()
                return "Torch sign-in confirmed"
            end if
            if currentURL contains "/reprocess" then
                set ticksSincePress to ticksSincePress + 1
                if ticksSincePress ≥ 8 then
                    if my pressContinue(my authWin()) then set ticksSincePress to 0
                end if
            end if
        end repeat
        error "Torch sign-in was not confirmed by Microsoft"
    on error errMsg number errNum
        my closeAuthTab()
        error "while " & stepName & ": " & errMsg number errNum
    end try
end run

on authWin()
    -- Chrome can replace or regroup the window it just opened (profile picker, tab moves), so follow the tab, not the window.
    tell application "Google Chrome"
        try
            if (id of tabs of authWindowRef) contains authTabId then return authWindowRef
        end try
        repeat with w in windows
            try
                if (id of tabs of w) contains authTabId then
                    set authWindowRef to contents of w
                    return authWindowRef
                end if
            end try
        end repeat
        repeat with w in windows
            try
                set tabIndex to 0
                repeat with t in tabs of w
                    set tabIndex to tabIndex + 1
                    set u to URL of t
                    if u contains "login.microsoftonline.com" or u contains "login.microsoft.com/device" then
                        set authTabId to id of t
                        set authWindowRef to contents of w
                        set active tab index of w to tabIndex
                        return authWindowRef
                    end if
                end repeat
            end try
        end repeat
    end tell
    error "The Microsoft sign-in window was closed"
end authWin

on authURL()
    set w to my authWin()
    tell application "Google Chrome"
        repeat with t in tabs of w
            if id of t is authTabId then return URL of t
        end repeat
        return URL of active tab of w
    end tell
end authURL

on closeAuthTab()
    try
        set w to my authWin()
        tell application "Google Chrome"
            if (count of tabs of w) is 1 then
                close w
            else
                repeat with t in tabs of w
                    if id of t is authTabId then
                        close t
                        exit repeat
                    end if
                end repeat
            end if
        end tell
    end try
end closeAuthTab

on focusAuthWindow(authWindow)
    -- Activating Chrome raises its last-used window, not necessarily ours, so raise the sign-in window
    -- through accessibility too. Returns true only when it is really the front window, so keystrokes land there.
    tell application "Google Chrome"
        activate
        try
            set index of authWindow to 1
        end try
    end tell
    set axWindow to my axAuthWindow(authWindow)
    if axWindow is missing value then return false
    repeat 5 times
        try
            tell application "System Events"
                tell process "Google Chrome"
                    set frontmost to true
                    perform action "AXRaise" of axWindow
                    try
                        set value of attribute "AXMain" of axWindow to true
                    end try
                    delay 0.2
                    if name of window 1 is name of axWindow then return true
                end tell
            end tell
        end try
        delay 0.3
    end repeat
    return false
end focusAuthWindow

on pressFocusedNamed(targetText, authWindow)
    if my focusAuthWindow(authWindow) is false then return false
    tell application "System Events"
        tell process "Google Chrome"
            try
                set focusedItem to value of attribute "AXFocusedUIElement" of it
                set focusedName to name of focusedItem as text
                if focusedName contains targetText then
                    key code 36
                    return true
                end if
            end try
        end tell
    end tell
    return false
end pressFocusedNamed

on axAuthWindow(authWindow)
    -- System Events can briefly see no Chrome windows (page loads, Space switches), so wait and match by title.
    set winTitle to ""
    try
        tell application "Google Chrome" to set winTitle to title of active tab of authWindow
    end try
    repeat 10 times
        try
            tell application "System Events"
                tell process "Google Chrome"
                    if winTitle is not "" then
                        set matches to (windows whose name contains winTitle)
                        if (count of matches) > 0 then return item 1 of matches
                    end if
                    if (count of windows) > 0 then return window 1
                end tell
            end tell
        end try
        delay 0.3
    end repeat
    return missing value
end axAuthWindow

on chooseAccount(accountEmail, authWindow, useMouse)
    -- One accessibility scan per pass; roles and names are fetched in bulk because per-element queries are very slow in Chrome.
    set jsResult to my chooseAccountJS(accountEmail, authWindow)
    if jsResult is not "unavailable" then return jsResult
    my focusAuthWindow(authWindow)
    set axWindow to my axAuthWindow(authWindow)
    if axWindow is missing value then return "none"
    tell application "System Events"
        tell process "Google Chrome"
            try
                set allItems to entire contents of axWindow
                set allRoles to role of entire contents of axWindow
                set allNames to name of entire contents of axWindow
            on error
                -- Bulk fetch can fail when some elements lack a name; fall back to the per-element scan.
                try
                    set allItems to entire contents of axWindow
                    set allRoles to {}
                    set allNames to {}
                    repeat with itemRef in allItems
                        set end of allRoles to ""
                        set end of allNames to ""
                        try
                            set item -1 of allRoles to role of itemRef as text
                            set item -1 of allNames to name of itemRef as text
                        end try
                    end repeat
                on error
                    return "none"
                end try
            end try
            if (count of allItems) is not (count of allRoles) or (count of allItems) is not (count of allNames) then return "none"
            set anotherIndex to 0
            set fieldIndex to 0
            repeat with i from 1 to count of allItems
                set itemRole to item i of allRoles
                set itemName to item i of allNames
                if itemName is missing value then set itemName to ""
                set itemName to itemName as text
                if itemRole is "AXButton" and itemName contains accountEmail then
                    if useMouse then
                        my mouseClick(item i of allItems)
                    else
                        my pressItem(item i of allItems)
                    end if
                    return "chosen"
                else if anotherIndex is 0 and itemRole is "AXButton" and itemName contains "Use another account" then
                    set anotherIndex to i
                else if fieldIndex is 0 and itemRole is "AXTextField" and (itemName contains "email" or itemName contains "Email" or itemName contains "phone" or itemName contains "Skype") then
                    set fieldIndex to i
                end if
            end repeat
            if anotherIndex is not 0 then
                my pressItem(item anotherIndex of allItems)
                return "another"
            end if
            if fieldIndex is not 0 then
                try
                    click item fieldIndex of allItems
                    keystroke accountEmail
                    key code 36
                    return "chosen"
                end try
            end if
        end tell
    end tell
    return "none"
end chooseAccount

on chooseAccountJS(accountEmail, authWindow)
    -- Clicks via page JavaScript, which works even when Chrome is on another Space. Needs Chrome's
    -- View > Developer > Allow JavaScript from Apple Events; returns "unavailable" when that is off.
    set js to "(function(email){" & ¬
        "email=email.toLowerCase();" & ¬
        "var els=Array.from(document.querySelectorAll('[role=button],[role=link],button,a,div.table,[data-test-id]'));" & ¬
        "var tile=els.filter(function(e){return (e.textContent||'').toLowerCase().indexOf(email)>=0||(e.getAttribute('data-test-id')||'').toLowerCase()===email;})" & ¬
        ".sort(function(a,b){return a.textContent.length-b.textContent.length;})[0];" & ¬
        "if(tile){tile.click();return 'chosen';}" & ¬
        "var other=els.filter(function(e){return /use another account/i.test(e.textContent||'');})[0];" & ¬
        "if(other){other.click();return 'another';}" & ¬
        "var f=document.querySelector('input[type=email],input[name=loginfmt]');" & ¬
        "if(f&&f.offsetParent!==null){f.focus();f.value=email;f.dispatchEvent(new Event('input',{bubbles:true}));f.dispatchEvent(new Event('change',{bubbles:true}));" & ¬
        "var b=document.querySelector('#idSIButton9,input[type=submit],button[type=submit]');if(b){b.click();return 'chosen';}}" & ¬
        "return 'none';})(" & quoted form of accountEmail & ")"
    try
        tell application "Google Chrome" to set r to execute active tab of authWindow javascript js
        if r is missing value then return "none"
        return r as text
    on error
        return "unavailable"
    end try
end chooseAccountJS

on pressContinue(authWindow)
    -- The "signing in on another device" page focuses "This wasn't me" by default, so Enter would reject the
    -- sign-in (AADSTS90135). Only press Enter once the focused button is Approve, tabbing back to it if needed.
    set js to "(function(){var b=Array.from(document.querySelectorAll('input[type=submit],button,[role=button]')).filter(function(e){return /^\\s*(approve|continue|yes)\\s*$/i.test(e.value||e.textContent||'');})[0];if(b){b.click();return 'pressed';}return 'none';})()"
    try
        tell application "Google Chrome" to set r to execute active tab of authWindow javascript js
        return (r as text) is "pressed"
    end try
    if my focusAuthWindow(authWindow) is false then return false
    tell application "System Events"
        tell process "Google Chrome"
            repeat 6 times
                try
                    set focusedName to name of (value of attribute "AXFocusedUIElement" of it) as text
                    if focusedName is in {"Approve", "Continue", "Yes"} then
                        key code 36
                        return true
                    end if
                end try
                key code 48 using shift down
                delay 0.2
            end repeat
        end tell
    end tell
    return false
end pressContinue

on mouseClick(itemRef)
    tell application "System Events"
        try
            set {x, y} to position of itemRef
            set {w, h} to size of itemRef
            click at {x + w div 2, y + h div 2}
        on error
            my pressItem(itemRef)
        end try
    end tell
end mouseClick

on pressItem(itemRef)
    tell application "System Events"
        try
            perform action "AXPress" of itemRef
        on error
            click itemRef
        end try
    end tell
end pressItem
