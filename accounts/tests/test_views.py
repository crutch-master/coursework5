from django.test import TestCase, Client
from django.urls import reverse

from accounts.models import CustomUser


class RegisterViewTests(TestCase):
    def setUp(self):
        self.client = Client()

    def test_successful_registration(self):
        response = self.client.post(
            reverse("register"),
            {
                "username": "newuser",
                "password1": "Str0ngP@ssw0rd!",
                "password2": "Str0ngP@ssw0rd!",
            },
        )
        self.assertEqual(response.status_code, 302)
        self.assertTrue(CustomUser.objects.filter(username="newuser").exists())

    def test_weak_password_rejected(self):
        response = self.client.post(
            reverse("register"),
            {
                "username": "newuser",
                "password1": "1",
                "password2": "1",
            },
        )
        self.assertEqual(response.status_code, 200)
        self.assertFalse(CustomUser.objects.filter(username="newuser").exists())
