package dev.example.moodlenative.runtime

import dev.example.moodlenative.data.CalendarPreferencesForm
import dev.example.moodlenative.data.LiveCalendarResult
import dev.example.moodlenative.features.CalendarSubscriptionPresentation
import dev.example.moodlenative.features.presentation
import dev.example.moodlenative.presentation.CalendarPreferencesPresentationForm

internal data class CalendarSubscriptionPresentationResult(
    val subscription: CalendarSubscriptionPresentation?,
    val statusMessage: String?,
)

internal fun CalendarPreferencesForm.toPresentationForm(): CalendarPreferencesPresentationForm =
    CalendarPreferencesPresentationForm(
        timeFormat = timeFormat,
        startWeekday = startWeekday,
        maxEvents = maxEvents,
        lookAhead = lookAhead,
        persistFilters = persistFilters,
    )

internal fun resolveCalendarSubscriptionPresentation(
    liveCalendarResult: LiveCalendarResult?,
): CalendarSubscriptionPresentationResult =
    CalendarSubscriptionPresentationResult(
        subscription = (liveCalendarResult as? LiveCalendarResult.Loaded)?.subscription?.presentation,
        statusMessage = when (liveCalendarResult) {
            is LiveCalendarResult.MissingSession -> "Moodle に接続してください。"
            is LiveCalendarResult.Loaded -> "生成済み: ${liveCalendarResult.loadedAt}"
            is LiveCalendarResult.Failed -> liveCalendarResult.message
            null -> null
        },
    )
