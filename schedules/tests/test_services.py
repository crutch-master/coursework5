from datetime import timedelta

from django.test import TestCase
from django.utils import timezone

from accounts.models import CustomUser
from schedules.models import Event, RecurrenceRule, Schedule
from schedules.services import (
    create_event_with_checks,
    detect_conflicts,
    get_user_schedules,
    update_event_with_checks,
    user_can_edit_schedule,
    user_can_view_schedule,
)
from teams.models import ScheduleShare, Team, TeamMembership


class DetectConflictsTests(TestCase):
    def setUp(self):
        self.user = CustomUser.objects.create_user(
            username="testuser", password="testpass123"
        )
        self.schedule = Schedule.objects.create(name="Test", owner=self.user)
        self.now = timezone.now()
        self.event = Event.objects.create(
            title="Existing",
            start_datetime=self.now,
            end_datetime=self.now + timedelta(hours=1),
            schedule=self.schedule,
            creator=self.user,
        )

    def test_overlapping_event_detected(self):
        conflicts = detect_conflicts(
            self.user,
            self.now + timedelta(minutes=30),
            self.now + timedelta(hours=1, minutes=30),
        )
        self.assertIn(self.event, conflicts)

    def test_non_overlapping_event_not_detected(self):
        conflicts = detect_conflicts(
            self.user,
            self.now + timedelta(hours=2),
            self.now + timedelta(hours=3),
        )
        self.assertNotIn(self.event, conflicts)

    def test_exclude_event(self):
        conflicts = detect_conflicts(
            self.user,
            self.now,
            self.now + timedelta(hours=1),
            exclude_event=self.event,
        )
        self.assertNotIn(self.event, conflicts)


class CreateEventWithChecksTests(TestCase):
    def setUp(self):
        self.user = CustomUser.objects.create_user(
            username="testuser", password="testpass123"
        )
        self.schedule = Schedule.objects.create(name="Test", owner=self.user)
        self.now = timezone.now()

    def test_creates_event_and_participants(self):
        participant = CustomUser.objects.create_user(
            username="participant", password="testpass123"
        )
        event = create_event_with_checks(
            {
                "title": "New Event",
                "start_datetime": self.now,
                "end_datetime": self.now + timedelta(hours=1),
                "schedule": self.schedule,
            },
            [participant],
            self.user,
        )
        self.assertEqual(event.title, "New Event")
        self.assertEqual(event.participants.count(), 1)


class UpdateEventWithChecksTests(TestCase):
    def setUp(self):
        self.user = CustomUser.objects.create_user(
            username="testuser", password="testpass123"
        )
        self.schedule = Schedule.objects.create(name="Test", owner=self.user)
        self.now = timezone.now()
        self.old_rule = RecurrenceRule.objects.create(frequency="daily", interval=1)
        self.event = Event.objects.create(
            title="Existing",
            start_datetime=self.now,
            end_datetime=self.now + timedelta(hours=1),
            schedule=self.schedule,
            creator=self.user,
            recurrence=self.old_rule,
        )

    def test_old_recurrence_deleted_on_change(self):
        new_rule = RecurrenceRule.objects.create(frequency="weekly", interval=2)
        update_event_with_checks(self.event, {"recurrence": new_rule}, [])
        self.assertFalse(RecurrenceRule.objects.filter(pk=self.old_rule.pk).exists())
        self.event.refresh_from_db()
        self.assertEqual(self.event.recurrence, new_rule)

    def test_old_recurrence_deleted_when_set_to_none(self):
        update_event_with_checks(self.event, {"recurrence": None}, [])
        self.assertFalse(RecurrenceRule.objects.filter(pk=self.old_rule.pk).exists())


class UserCanEditScheduleTests(TestCase):
    def setUp(self):
        self.owner = CustomUser.objects.create_user(
            username="owner", password="testpass123"
        )
        self.viewer = CustomUser.objects.create_user(
            username="viewer", password="testpass123"
        )
        self.editor = CustomUser.objects.create_user(
            username="editor", password="testpass123"
        )
        self.schedule = Schedule.objects.create(name="Test", owner=self.owner)
        ScheduleShare.objects.create(
            schedule=self.schedule, shared_with_user=self.viewer, permission="view"
        )
        ScheduleShare.objects.create(
            schedule=self.schedule, shared_with_user=self.editor, permission="edit"
        )

    def test_owner_can_edit(self):
        self.assertTrue(user_can_edit_schedule(self.owner, self.schedule))

    def test_editor_can_edit(self):
        self.assertTrue(user_can_edit_schedule(self.editor, self.schedule))

    def test_viewer_cannot_edit(self):
        self.assertFalse(user_can_edit_schedule(self.viewer, self.schedule))

    def test_unrelated_user_cannot_edit(self):
        other = CustomUser.objects.create_user(username="other", password="testpass123")
        self.assertFalse(user_can_edit_schedule(other, self.schedule))

    def test_team_edit_share_allows_edit(self):
        team = Team.objects.create(name="Team", created_by=self.owner)
        TeamMembership.objects.create(user=self.viewer, team=team, role="member")
        ScheduleShare.objects.create(
            schedule=self.schedule, shared_with_team=team, permission="edit"
        )
        self.assertTrue(user_can_edit_schedule(self.viewer, self.schedule))


class UserCanViewScheduleTests(TestCase):
    def setUp(self):
        self.owner = CustomUser.objects.create_user(
            username="owner", password="testpass123"
        )
        self.viewer = CustomUser.objects.create_user(
            username="viewer", password="testpass123"
        )
        self.schedule = Schedule.objects.create(name="Test", owner=self.owner)
        ScheduleShare.objects.create(
            schedule=self.schedule, shared_with_user=self.viewer, permission="view"
        )

    def test_owner_can_view(self):
        self.assertTrue(user_can_view_schedule(self.owner, self.schedule))

    def test_shared_user_can_view(self):
        self.assertTrue(user_can_view_schedule(self.viewer, self.schedule))

    def test_unrelated_user_cannot_view(self):
        other = CustomUser.objects.create_user(username="other", password="testpass123")
        self.assertFalse(user_can_view_schedule(other, self.schedule))


class GetUserSchedulesTests(TestCase):
    def setUp(self):
        self.owner = CustomUser.objects.create_user(
            username="owner", password="testpass123"
        )
        self.viewer = CustomUser.objects.create_user(
            username="viewer", password="testpass123"
        )
        self.schedule = Schedule.objects.create(name="Owned", owner=self.owner)
        self.shared_schedule = Schedule.objects.create(
            name="Shared",
            owner=CustomUser.objects.create_user(
                username="other", password="testpass123"
            ),
        )
        ScheduleShare.objects.create(
            schedule=self.shared_schedule,
            shared_with_user=self.viewer,
            permission="view",
        )

    def test_owner_sees_owned_schedule(self):
        qs = get_user_schedules(self.owner)
        self.assertIn(self.schedule, qs)

    def test_viewer_sees_shared_schedule(self):
        qs = get_user_schedules(self.viewer)
        self.assertIn(self.shared_schedule, qs)

    def test_viewer_does_not_see_unshared(self):
        qs = get_user_schedules(self.viewer)
        self.assertNotIn(self.schedule, qs)
