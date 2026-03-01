on run argv
    set accountId to item 1 of argv
    tell application "Mail"
        set inboxAccount to account id accountId
        set inboxFolder to mailbox "INBOX" of inboxAccount

        -- Get unread messages only
        set unreadMessages to every message of inboxFolder whose read status is false

        if (count of unreadMessages) = 0 then
            return "NO_UNREAD_EMAILS"
        end if

        -- Return as text with sender|subject|content format, one per line
        set output to ""
        repeat with msg in unreadMessages
            set senderStr to sender of msg as string
            set subjectStr to subject of msg as string
            set contentStr to content of msg as string

            if output is not "" then
                set output to output & "|||"
            end if
            -- Use ||| as delimiter since | might appear in email addresses
            set output to output & senderStr & "|" & subjectStr & "|" & contentStr
        end repeat

        return output
    end tell
end run
