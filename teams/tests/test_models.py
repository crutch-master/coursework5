from django.core.exceptions import ValidationError
from django.test import TestCase

from accounts.models import CustomUser
from schedules.models import Schedule
from teams.models import ScheduleShare, Team


class ScheduleShareTargetValidationTests(TestCase):
    def setUp(self):
        self.owner = CustomUser.objects.create_user(
            username="owner", password="testpass123"
        )
        self.schedule = Schedule.objects.create(name="Test", owner=self.owner)
        self.user = CustomUser.objects.create_user(
            username="target", password="testpass123"
        )
        self.team = Team.objects.create(name="Team", created_by=self.owner)

    def test_share_with_user_is_valid(self):
        share = ScheduleShare(
            schedule=self.schedule, shared_with_user=self.user, permission="view"
        )
        share.full_clean()

    def test_share_with_team_is_valid(self):
        share = ScheduleShare(
            schedule=self.schedule, shared_with_team=self.team, permission="view"
        )
        share.full_clean()

    def test_share_with_both_targets_is_invalid(self):
        share = ScheduleShare(
            schedule=self.schedule,
            shared_with_user=self.user,
            shared_with_team=self.team,
            permission="view",
        )
        with self.assertRaises(ValidationError):
            share.full_clean()

    def test_share_with_no_targets_is_invalid(self):
        share = ScheduleShare(schedule=self.schedule, permission="view")
        with self.assertRaises(ValidationError):
            share.full_clean()


class ScheduleShareNullUniquenessTests(TestCase):
    def setUp(self):
        self.owner = CustomUser.objects.create_user(
            username="owner", password="testpass123"
        )
        self.schedule = Schedule.objects.create(name="Test", owner=self.owner)
        self.user = CustomUser.objects.create_user(
            username="target", password="testpass123"
        )

    def test_duplicate_user_share_prevented(self):
        ScheduleShare.objects.create(
            schedule=self.schedule, shared_with_user=self.user, permission="view"
        )
        share2 = ScheduleShare(
            schedule=self.schedule, shared_with_user=self.user, permission="edit"
        )
        with self.assertRaises(ValidationError):
            share2.full_clean()

    def test_different_users_can_share_same_schedule(self):
        user2 = CustomUser.objects.create_user(
            username="target2", password="testpass123"
        )
        ScheduleShare.objects.create(
            schedule=self.schedule, shared_with_user=self.user, permission="view"
        )
        share2 = ScheduleShare(
            schedule=self.schedule, shared_with_user=user2, permission="edit"
        )
        share2.full_clean()
