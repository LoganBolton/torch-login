on run argv
    set deviceURL to item 1 of argv
    set deviceCode to item 2 of argv
    set accountEmail to item 3 of argv
    if deviceURL does not start with "https://login.microsoft.com/device" and deviceURL does not start with "https://microsoft.com/devicelogin" then error "Unexpected device sign-in URL"

    set authWindow to missing value
    try
        tell application "Google Chrome"
            set authWindow to make new window
            set URL of active tab of authWindow to deviceURL
            activate
            set index of authWindow to 1
        end tell

        set ready to false
        repeat 40 times
            delay 0.5
            tell application "Google Chrome" to set currentURL to URL of active tab of authWindow
            if currentURL contains "login.microsoftonline.com/common/oauth2/deviceauth" then
                set ready to true
                exit repeat
            end if
        end repeat
        if ready is false then error "Chrome did not show the Microsoft device code page"

        delay 1
        my focusAuthWindow(authWindow)
        tell application "System Events"
            keystroke deviceCode
            key code 36
        end tell

        set accountChosen to false
        repeat 80 times
            delay 0.5
            tell application "Google Chrome" to set currentURL to URL of active tab of authWindow
            if currentURL contains "/appverify" then exit repeat
            if accountChosen and currentURL does not contain "/deviceauth" then exit repeat
            if accountChosen is false then
                if my pressFocusedNamed(accountEmail, authWindow) then
                    set accountChosen to true
                else if my pressButton(accountEmail, authWindow) then
                    set accountChosen to true
                else if my pressButton("Use another account", authWindow) then
                    delay 1
                else if my enterEmail(accountEmail, authWindow) then
                    set accountChosen to true
                end if
            end if
        end repeat
        if accountChosen is false and currentURL does not contain "/appverify" then error "Could not select the configured account on the Microsoft account page"
        if accountChosen and currentURL contains "/deviceauth" then error "The configured account button did not advance the sign-in page"

        set continuePressed to false
        repeat 120 times
            delay 0.5
            tell application "Google Chrome" to set currentURL to URL of active tab of authWindow
            if currentURL contains "/appverify" then
                tell application "Google Chrome" to close authWindow
                return "Torch sign-in confirmed"
            end if
            if continuePressed is false and currentURL contains "/reprocess" then
                my focusAuthWindow(authWindow)
                tell application "System Events" to key code 36
                set continuePressed to true
            end if
        end repeat
        error "Torch sign-in was not confirmed by Microsoft"
    on error errMsg number errNum
        if authWindow is not missing value then
            try
                tell application "Google Chrome" to close authWindow
            end try
        end if
        error errMsg number errNum
    end try
end run

on focusAuthWindow(authWindow)
    tell application "Google Chrome"
        activate
        set index of authWindow to 1
    end tell
end focusAuthWindow

on pressFocusedNamed(targetText, authWindow)
    my focusAuthWindow(authWindow)
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

on pressButton(targetText, authWindow)
    my focusAuthWindow(authWindow)
    tell application "System Events"
        tell process "Google Chrome"
            repeat with itemRef in (entire contents of front window)
                try
                    set itemRole to role of itemRef as text
                    set itemName to name of itemRef as text
                    if itemRole is "AXButton" and itemName contains targetText then
                        try
                            perform action "AXPress" of itemRef
                        on error
                            click itemRef
                        end try
                        return true
                    end if
                end try
            end repeat
        end tell
    end tell
    return false
end pressButton

on enterEmail(accountEmail, authWindow)
    my focusAuthWindow(authWindow)
    tell application "System Events"
        tell process "Google Chrome"
            repeat with itemRef in (entire contents of front window)
                try
                    set itemRole to role of itemRef as text
                    set itemName to name of itemRef as text
                    if itemRole is "AXTextField" and (itemName contains "email" or itemName contains "Email" or itemName contains "phone" or itemName contains "Skype") then
                        click itemRef
                        keystroke accountEmail
                        key code 36
                        return true
                    end if
                end try
            end repeat
        end tell
    end tell
    return false
end enterEmail
