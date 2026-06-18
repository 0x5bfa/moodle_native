package dev.example.moodlenative.features

data class CalendarSubscriptionPresentation(
    val webcalURL: String,
    val httpsURL: String,
)

val LmsCalendarSubscription.presentation: CalendarSubscriptionPresentation
    get() = CalendarSubscriptionPresentation(
        webcalURL = webcalURI.toString(),
        httpsURL = uri.toString(),
    )
