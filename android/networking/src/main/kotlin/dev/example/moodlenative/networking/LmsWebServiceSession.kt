package dev.example.moodlenative.networking

data class LmsWebServiceSession(
    val siteURL: String,
    val token: String,
    val userID: Int? = null,
)
