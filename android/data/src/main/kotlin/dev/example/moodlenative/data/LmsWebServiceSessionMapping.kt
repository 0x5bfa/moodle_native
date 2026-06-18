package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.networking.LmsWebServiceSession

internal fun LmsAuthenticationSession.toLmsWebServiceSession(): LmsWebServiceSession =
    LmsWebServiceSession(
        siteURL = siteURL,
        token = token,
        userID = userID,
    )
