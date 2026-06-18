package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.features.LmsCalendarSubscription
import dev.example.moodlenative.networking.LmsWebServiceClient

internal class LmsCalendarWebServiceGateway(
    session: LmsAuthenticationSession,
) : CalendarGateway {
    private val client = LmsWebServiceClient(session.toLmsWebServiceSession())

    override suspend fun makeCalendarSubscription(userID: Int?): LmsCalendarSubscription =
        client.makeCalendarSubscription(userID = userID).let { subscription ->
            LmsCalendarSubscription(uri = subscription.uri)
        }
}
