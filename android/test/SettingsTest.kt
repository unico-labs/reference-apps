package io.unico.reference.settings

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SettingsTest {
    private val filled = Settings(account = "acme", tenant = "tenant", sdkKey = "key", privateKeyPem = "pem")

    @Test
    fun `is complete with the credentials and the SDK key`() {
        assertTrue(filled.isComplete)
    }

    @Test
    fun `is not complete without the SDK key`() {
        assertFalse(filled.copy(sdkKey = " ").isComplete)
    }

    @Test
    fun `has credentials before the SDK key is added`() {
        assertTrue(filled.copy(sdkKey = "").hasCredentials)
    }

    @Test
    fun `has no credentials without the private key`() {
        assertFalse(filled.copy(privateKeyPem = "").hasCredentials)
    }
}
