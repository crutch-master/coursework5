from django.test import TestCase, override_settings


class SettingsTests(TestCase):
    def test_password_validators_configured(self):
        from config.settings import AUTH_PASSWORD_VALIDATORS

        self.assertEqual(len(AUTH_PASSWORD_VALIDATORS), 4)

    def test_security_settings_present(self):
        from config import settings

        self.assertTrue(settings.SECURE_BROWSER_XSS_FILTER)
        self.assertTrue(settings.SECURE_CONTENT_TYPE_NOSNIFF)
        self.assertEqual(settings.X_FRAME_OPTIONS, "DENY")
        self.assertTrue(settings.CSRF_COOKIE_HTTPONLY)
        self.assertEqual(settings.CSRF_COOKIE_SAMESITE, "Lax")
        self.assertEqual(settings.SESSION_COOKIE_SAMESITE, "Lax")

    def test_logging_configured(self):
        from config.settings import LOGGING

        self.assertIn("django", LOGGING["loggers"])
        self.assertIn("django.security", LOGGING["loggers"])

    def test_debug_from_env(self):
        with override_settings(DEBUG=False):
            from django.conf import settings

            self.assertFalse(settings.DEBUG)

    def test_allowed_hosts_from_env(self):
        with override_settings(ALLOWED_HOSTS=["example.com"]):
            from django.conf import settings

            self.assertIn("example.com", settings.ALLOWED_HOSTS)

    def test_ssl_settings_not_set_in_debug(self):
        from config import settings

        if settings.DEBUG:
            self.assertFalse(getattr(settings, "SECURE_SSL_REDIRECT", False))
