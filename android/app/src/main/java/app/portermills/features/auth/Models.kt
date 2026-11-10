package app.portermills.features.auth

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class MagicLinkRequest(val email: String)

@Serializable
data class VerifyTokenRequest(val token: String)

@Serializable
data class AuthResponse(
    val token: String,
    val user: AuthUser,
)

@Serializable
data class AuthUser(
    val id: String,
    val name: String,
    val email: String,
    @SerialName("family_id") val familyId: String,
)
