from datetime import timedelta

from django.core.exceptions import ValidationError
from django.test import TestCase
from django.utils import timezone

from accounts.models import CustomUser
from schedules.models import Event, RecurrenceRule, Schedule


class ScheduleModelTests(TestCase):
    def setUp(self):
        self.user = CustomUser.objects.create_user(
            username="testuser", password="testpass123"
        )

    def test_valid_hex_color(self):
        schedule = Schedule(name="Test", color="#abc123", owner=self.user)
        schedule.full_clean()

    def test_invalid_color_non_hex(self):
        schedule = Schedule(name="Test", color="red", owner=self.user)
        with self.assertRaises(ValidationError):
            schedule.full_clean()

    def test_invalid_color_short(self):
        schedule = Schedule(name="Test", color="#abc", owner=self.user)
        with self.assertRaises(ValidationError):
            schedule.full_clean()

    def test_invalid_color_no_hash(self):
        schedule = Schedule(name="Test", color="abc123", owner=self.user)
        with self.assertRaises(ValidationError):
            schedule.full_clean()

    def test_default_color_is_valid(self):
        schedule = Schedule(name="Test", owner=self.user)
        schedule.full_clean()


class RecurrenceRuleModelTests(TestCase):
    def test_valid_days_of_week(self):
        rule = RecurrenceRule(frequency="weekly", days_of_week="MO,TU,WE")
        rule.full_clean()

    def test_empty_days_of_week_is_valid(self):
        rule = RecurrenceRule(frequency="daily", days_of_week="")
        rule.full_clean()

    def test_invalid_day_abbreviation(self):
        rule = RecurrenceRule(frequency="weekly", days_of_week="MO,TUE")
        with self.assertRaises(ValidationError):
            rule.full_clean()

    def test_trailing_comma_invalid(self):
        rule = RecurrenceRule(frequency="weekly", days_of_week="MO,")
        with self.assertRaises(ValidationError):
            rule.full_clean()

    def test_single_day_valid(self):
        rule = RecurrenceRule(frequency="weekly", days_of_week="FR")
        rule.full_clean()


class EventModelTests(TestCase):
    def setUp(self):
        self.user = CustomUser.objects.create_user(
            username="testuser", password="testpass123"
        )
        self.schedule = Schedule.objects.create(name="Test", owner=self.user)

    def test_end_after_start_is_valid(self):
        now = timezone.now()
        event = Event(
            title="Test",
            start_datetime=now,
            end_datetime=now + timedelta(hours=1),
            schedule=self.schedule,
            creator=self.user,
        )
        event.full_clean()

    def test_end_before_start_is_invalid(self):
        now = timezone.now()
        event = Event(
            title="Test",
            start_datetime=now + timedelta(hours=1),
            end_datetime=now,
            schedule=self.schedule,
            creator=self.user,
        )
        with self.assertRaises(ValidationError):
            event.full_clean()

    def test_end_equals_start_is_invalid(self):
        now = timezone.now()
        event = Event(
            title="Test",
            start_datetime=now,
            end_datetime=now,
            schedule=self.schedule,
            creator=self.user,
        )
        with self.assertRaises(ValidationError):
            event.full_clean()
