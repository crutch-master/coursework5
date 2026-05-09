from datetime import timedelta

from django.test import TestCase, Client
from django.urls import reverse
from django.utils import timezone

from accounts.models import CustomUser
from schedules.models import Event, EventParticipant, Schedule
from teams.models import ScheduleShare


class ScheduleViewPermissionTests(TestCase):
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
        self.client = Client()

    def test_owner_can_update_schedule(self):
        self.client.login(username="owner", password="testpass123")
        response = self.client.post(
            reverse("schedules:schedule-update", kwargs={"pk": self.schedule.pk}),
            {"name": "Updated", "description": "", "color": "#3788d8"},
        )
        self.assertEqual(response.status_code, 302)

    def test_viewer_cannot_update_schedule(self):
        self.client.login(username="viewer", password="testpass123")
        response = self.client.post(
            reverse("schedules:schedule-update", kwargs={"pk": self.schedule.pk}),
            {"name": "Hacked", "description": "", "color": "#3788d8"},
        )
        self.assertEqual(response.status_code, 404)

    def test_owner_can_delete_schedule(self):
        self.client.login(username="owner", password="testpass123")
        response = self.client.post(
            reverse("schedules:schedule-delete", kwargs={"pk": self.schedule.pk}),
        )
        self.assertEqual(response.status_code, 302)

    def test_viewer_cannot_delete_schedule(self):
        self.client.login(username="viewer", password="testpass123")
        response = self.client.post(
            reverse("schedules:schedule-delete", kwargs={"pk": self.schedule.pk}),
        )
        self.assertEqual(response.status_code, 404)


class EventCreatePermissionTests(TestCase):
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
        self.client = Client()
        self.now = timezone.now()

    def test_viewer_cannot_create_event(self):
        self.client.login(username="viewer", password="testpass123")
        response = self.client.post(
            reverse("schedules:event-create", kwargs={"schedule_pk": self.schedule.pk}),
            {
                "title": "Bad Event",
                "start_datetime": self.now.strftime("%Y-%m-%dT%H:%M"),
                "end_datetime": (self.now + timedelta(hours=1)).strftime(
                    "%Y-%m-%dT%H:%M"
                ),
            },
        )
        self.assertEqual(response.status_code, 403)

    def test_editor_can_create_event(self):
        self.client.login(username="editor", password="testpass123")
        response = self.client.post(
            reverse("schedules:event-create", kwargs={"schedule_pk": self.schedule.pk}),
            {
                "title": "Good Event",
                "description": "",
                "start_datetime": self.now.strftime("%Y-%m-%dT%H:%M"),
                "end_datetime": (self.now + timedelta(hours=1)).strftime(
                    "%Y-%m-%dT%H:%M"
                ),
                "location": "",
            },
        )
        self.assertEqual(response.status_code, 302)

    def test_owner_can_create_event(self):
        self.client.login(username="owner", password="testpass123")
        response = self.client.post(
            reverse("schedules:event-create", kwargs={"schedule_pk": self.schedule.pk}),
            {
                "title": "Owner Event",
                "description": "",
                "start_datetime": self.now.strftime("%Y-%m-%dT%H:%M"),
                "end_datetime": (self.now + timedelta(hours=1)).strftime(
                    "%Y-%m-%dT%H:%M"
                ),
                "location": "",
            },
        )
        self.assertEqual(response.status_code, 302)


class EventUpdatePermissionTests(TestCase):
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
        self.now = timezone.now()
        self.event = Event.objects.create(
            title="Test Event",
            start_datetime=self.now,
            end_datetime=self.now + timedelta(hours=1),
            schedule=self.schedule,
            creator=self.owner,
        )
        self.client = Client()

    def test_viewer_cannot_update_event(self):
        self.client.login(username="viewer", password="testpass123")
        response = self.client.post(
            reverse("schedules:event-update", kwargs={"pk": self.event.pk}),
            {"title": "Hacked"},
        )
        self.assertIn(response.status_code, [403, 404])

    def test_editor_can_update_event(self):
        self.client.login(username="editor", password="testpass123")
        response = self.client.post(
            reverse("schedules:event-update", kwargs={"pk": self.event.pk}),
            {
                "title": "Updated",
                "description": "",
                "start_datetime": self.now.strftime("%Y-%m-%dT%H:%M"),
                "end_datetime": (self.now + timedelta(hours=1)).strftime(
                    "%Y-%m-%dT%H:%M"
                ),
                "location": "",
            },
        )
        self.assertEqual(response.status_code, 302)


class EventDeletePermissionTests(TestCase):
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
        self.now = timezone.now()
        self.event = Event.objects.create(
            title="Test Event",
            start_datetime=self.now,
            end_datetime=self.now + timedelta(hours=1),
            schedule=self.schedule,
            creator=self.owner,
        )
        self.client = Client()

    def test_viewer_cannot_delete_event(self):
        self.client.login(username="viewer", password="testpass123")
        response = self.client.post(
            reverse("schedules:event-delete", kwargs={"pk": self.event.pk}),
        )
        self.assertEqual(response.status_code, 403)


class EventRSVPViewTests(TestCase):
    def setUp(self):
        self.owner = CustomUser.objects.create_user(
            username="owner", password="testpass123"
        )
        self.participant_user = CustomUser.objects.create_user(
            username="participant", password="testpass123"
        )
        self.non_participant = CustomUser.objects.create_user(
            username="nonparticipant", password="testpass123"
        )
        self.schedule = Schedule.objects.create(name="Test", owner=self.owner)
        ScheduleShare.objects.create(
            schedule=self.schedule,
            shared_with_user=self.participant_user,
            permission="view",
        )
        ScheduleShare.objects.create(
            schedule=self.schedule,
            shared_with_user=self.non_participant,
            permission="view",
        )
        self.now = timezone.now()
        self.event = Event.objects.create(
            title="Test Event",
            start_datetime=self.now,
            end_datetime=self.now + timedelta(hours=1),
            schedule=self.schedule,
            creator=self.owner,
        )
        self.client = Client()

    def test_non_participant_with_schedule_access_cannot_rsvp(self):
        self.client.login(username="nonparticipant", password="testpass123")
        response = self.client.post(
            reverse("schedules:event-rsvp", kwargs={"pk": self.event.pk}),
            {"rsvp_status": "accepted"},
        )
        self.assertEqual(response.status_code, 302)
        self.assertFalse(
            EventParticipant.objects.filter(
                user=self.non_participant, event=self.event
            ).exists()
        )

    def test_participant_can_rsvp(self):
        participant = EventParticipant.objects.create(
            user=self.participant_user, event=self.event
        )
        self.client.login(username="participant", password="testpass123")
        response = self.client.post(
            reverse("schedules:event-rsvp", kwargs={"pk": self.event.pk}),
            {"rsvp_status": "accepted"},
        )
        self.assertEqual(response.status_code, 302)
        participant.refresh_from_db()
        self.assertEqual(participant.rsvp_status, "accepted")

    def test_user_without_schedule_access_gets_404(self):
        CustomUser.objects.create_user(username="stranger", password="testpass123")
        self.client.login(username="stranger", password="testpass123")
        response = self.client.post(
            reverse("schedules:event-rsvp", kwargs={"pk": self.event.pk}),
            {"rsvp_status": "accepted"},
        )
        self.assertEqual(response.status_code, 404)


class EventDetailViewContextTests(TestCase):
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
        self.now = timezone.now()
        self.event = Event.objects.create(
            title="Test Event",
            start_datetime=self.now,
            end_datetime=self.now + timedelta(hours=1),
            schedule=self.schedule,
            creator=self.owner,
        )
        self.client = Client()

    def test_viewer_sees_no_edit_links(self):
        self.client.login(username="viewer", password="testpass123")
        response = self.client.get(
            reverse("schedules:event-detail", kwargs={"pk": self.event.pk}),
        )
        self.assertEqual(response.context["can_edit"], False)

    def test_owner_sees_edit_links(self):
        self.client.login(username="owner", password="testpass123")
        response = self.client.get(
            reverse("schedules:event-detail", kwargs={"pk": self.event.pk}),
        )
        self.assertEqual(response.context["can_edit"], True)
