package dev.example.moodlenative.features
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SettingsPreferencesPresentationSupportTest {
    @Test
    fun messagePresentationIncludesContactScopesAndInstantMessageProcessors() {
        val presentation = LmsMessagePreferences(
            notificationPreferences = preferences(disableAll = true),
            blockNonContacts = 2,
            enterToSend = true,
        ).presentation(allowsSiteMessaging = false)

        assertEquals(2, presentation.selectedContactScopeValue)
        assertEquals("サイト全体", presentation.selectedContactScopeLabel)
        assertEquals(
            listOf("同じコースの参加者", "連絡先のみ", "サイト全体"),
            presentation.contactScopeOptions.map { it.label },
        )
        assertTrue(presentation.areNotificationsDisabled)
        assertEquals(listOf("airnotifier", "email"), presentation.instantMessageProcessors.map { it.processorName })
        assertEquals("Mobile", presentation.instantMessageProcessors.first().title)
        assertFalse(presentation.instantMessageProcessors.first().checked)
    }

    @Test
    fun notificationPresentationSelectsRequestedProcessorAndBuildsRows() {
        val presentation = preferences().presentation(currentSelectedProcessorName = "email")

        assertTrue(presentation.enableAll)
        assertEquals(1, presentation.componentGroupCount)
        assertEquals("email", presentation.selectedProcessor?.name)
        assertEquals(listOf("Mobile", "Email"), presentation.processors.map { it.displayName })

        val notification = presentation.components.single().notifications.single()
        assertEquals("message_provider_moodle_instantmessage", notification.preferenceKey)
        assertEquals("インスタントメッセージ", notification.title)
        assertEquals("email", notification.directToggle?.processorName)
        assertTrue(notification.directToggle?.checked == true)
        assertEquals(emptyList<LegacyNotificationPreferenceStatePresentation>(), notification.legacyStates)
    }

    @Test
    fun notificationPresentationUsesAirnotifierFallbackAndLegacyStates() {
        val presentation = preferences(components = listOf(legacyComponent()))
            .presentation(currentSelectedProcessorName = "missing")

        assertEquals("airnotifier", presentation.selectedProcessor?.name)
        val notification = presentation.components.single().notifications.single()
        assertNull(notification.directToggle)
        assertEquals(listOf("loggedin", "loggedoff"), notification.legacyStates.map { it.stateName })
        assertEquals(listOf(false, true), notification.legacyStates.map { it.checked })
    }

    @Test
    fun messageContactScopeLabelHandlesUnknownValue() {
        assertEquals("未設定", messageContactScopeLabel(99))
    }

    private companion object {
        fun preferences(
            disableAll: Boolean = false,
            components: List<LmsNotificationPreferencesComponent> = listOf(messageComponent()),
        ): LmsNotificationPreferences =
            LmsNotificationPreferences(
                userID = 99,
                disableAll = disableAll,
                processors = listOf(
                    LmsNotificationPreferencesProcessor(
                        displayName = "Mobile",
                        name = "airnotifier",
                        hasSettings = false,
                        contextID = null,
                        userConfigured = true,
                    ),
                    LmsNotificationPreferencesProcessor(
                        displayName = "Email",
                        name = "email",
                        hasSettings = false,
                        contextID = null,
                        userConfigured = true,
                    ),
                ),
                components = components,
            )

        fun messageComponent(): LmsNotificationPreferencesComponent =
            LmsNotificationPreferencesComponent(
                displayName = "メッセージ",
                notifications = listOf(
                    LmsNotificationPreference(
                        displayName = "インスタントメッセージ",
                        preferenceKey = "message_provider_moodle_instantmessage",
                        processors = listOf(
                            LmsNotificationPreferenceProcessor(
                                displayName = "Mobile",
                                name = "airnotifier",
                                locked = false,
                                lockedMessage = null,
                                userConfigured = true,
                                enabled = false,
                                loggedIn = null,
                                loggedOff = null,
                            ),
                            LmsNotificationPreferenceProcessor(
                                displayName = "Email",
                                name = "email",
                                locked = false,
                                lockedMessage = null,
                                userConfigured = true,
                                enabled = true,
                                loggedIn = null,
                                loggedOff = null,
                            ),
                        ),
                    ),
                ),
            )

        fun legacyComponent(): LmsNotificationPreferencesComponent =
            LmsNotificationPreferencesComponent(
                displayName = "フォーラム",
                notifications = listOf(
                    LmsNotificationPreference(
                        displayName = "フォーラム投稿",
                        preferenceKey = "message_provider_mod_forum_posts",
                        processors = listOf(
                            LmsNotificationPreferenceProcessor(
                                displayName = "Mobile",
                                name = "airnotifier",
                                locked = false,
                                lockedMessage = null,
                                userConfigured = true,
                                enabled = null,
                                loggedIn = LmsNotificationPreferenceProcessorState(
                                    name = "loggedin",
                                    displayName = "オンライン",
                                    checked = false,
                                ),
                                loggedOff = LmsNotificationPreferenceProcessorState(
                                    name = "loggedoff",
                                    displayName = "オフライン",
                                    checked = true,
                                ),
                            ),
                        ),
                    ),
                ),
            )
    }
}
