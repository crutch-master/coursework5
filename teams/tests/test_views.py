from django.test import TestCase, Client
from django.urls import reverse

from accounts.models import CustomUser
from schedules.models import Schedule
from teams.models import ScheduleShare, Team, TeamMembership


class ScheduleShareCreateViewTests(TestCase):
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

    def test_owner_can_access_share_create(self):
        self.client.login(username="owner", password="testpass123")
        response = self.client.get(reverse("teams:schedule-share-create"))
        self.assertEqual(response.status_code, 200)

    def test_viewer_schedule_queryset_excludes_shared_schedules(self):
        self.client.login(username="viewer", password="testpass123")
        from teams.forms import ScheduleShareForm

        form = ScheduleShareForm(user=self.viewer)
        self.assertNotIn(self.schedule, form.fields["schedule"].queryset)

    def test_owner_schedule_queryset_includes_owned_schedules(self):
        self.client.login(username="owner", password="testpass123")
        from teams.forms import ScheduleShareForm

        form = ScheduleShareForm(user=self.owner)
        self.assertIn(self.schedule, form.fields["schedule"].queryset)

    def test_invalid_schedule_id_get_param_ignored(self):
        self.client.login(username="owner", password="testpass123")
        response = self.client.get(
            reverse("teams:schedule-share-create") + "?schedule=99999"
        )
        self.assertEqual(response.status_code, 200)


class TeamRemoveMemberViewTests(TestCase):
    def setUp(self):
        self.admin = CustomUser.objects.create_user(
            username="admin", password="testpass123"
        )
        self.member = CustomUser.objects.create_user(
            username="member", password="testpass123"
        )
        self.team = Team.objects.create(name="Team", created_by=self.admin)
        TeamMembership.objects.create(user=self.admin, team=self.team, role="admin")
        TeamMembership.objects.create(user=self.member, team=self.team, role="member")
        self.client = Client()

    def test_get_not_allowed(self):
        self.client.login(username="admin", password="testpass123")
        response = self.client.get(
            reverse(
                "teams:team-remove-member",
                kwargs={"pk": self.team.pk, "user_pk": self.member.pk},
            ),
        )
        self.assertEqual(response.status_code, 405)

    def test_last_admin_cannot_leave(self):
        self.client.login(username="admin", password="testpass123")
        response = self.client.post(
            reverse(
                "teams:team-remove-member",
                kwargs={"pk": self.team.pk, "user_pk": self.admin.pk},
            ),
        )
        self.assertEqual(response.status_code, 302)
        self.assertTrue(
            TeamMembership.objects.filter(user=self.admin, team=self.team).exists()
        )

    def test_admin_can_remove_member(self):
        self.client.login(username="admin", password="testpass123")
        response = self.client.post(
            reverse(
                "teams:team-remove-member",
                kwargs={"pk": self.team.pk, "user_pk": self.member.pk},
            ),
        )
        self.assertEqual(response.status_code, 302)
        self.assertFalse(
            TeamMembership.objects.filter(user=self.member, team=self.team).exists()
        )

    def test_second_admin_can_leave(self):
        admin2 = CustomUser.objects.create_user(
            username="admin2", password="testpass123"
        )
        TeamMembership.objects.create(user=admin2, team=self.team, role="admin")
        self.client.login(username="admin2", password="testpass123")
        response = self.client.post(
            reverse(
                "teams:team-remove-member",
                kwargs={"pk": self.team.pk, "user_pk": admin2.pk},
            ),
        )
        self.assertEqual(response.status_code, 302)
        self.assertFalse(
            TeamMembership.objects.filter(user=admin2, team=self.team).exists()
        )


class TeamListViewContextTests(TestCase):
    def setUp(self):
        self.admin = CustomUser.objects.create_user(
            username="admin", password="testpass123"
        )
        self.member = CustomUser.objects.create_user(
            username="member", password="testpass123"
        )
        self.team = Team.objects.create(name="Team", created_by=self.admin)
        TeamMembership.objects.create(user=self.admin, team=self.team, role="admin")
        TeamMembership.objects.create(user=self.member, team=self.team, role="member")
        self.client = Client()

    def test_admin_sees_admin_team_ids(self):
        self.client.login(username="admin", password="testpass123")
        response = self.client.get(reverse("teams:team-list"))
        self.assertIn(self.team.pk, response.context["admin_team_ids"])

    def test_member_does_not_see_admin_team_ids(self):
        self.client.login(username="member", password="testpass123")
        response = self.client.get(reverse("teams:team-list"))
        self.assertNotIn(self.team.pk, response.context["admin_team_ids"])
