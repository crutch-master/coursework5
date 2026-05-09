from django.core.exceptions import ValidationError
from django.test import TestCase

from accounts.models import CustomUser
from teams.models import Team
from teams.services import (
    add_team_member,
    get_teams_for_user,
    is_team_admin,
    share_schedule_with_team,
    share_schedule_with_user,
)
from schedules.models import Schedule


class IsTeamAdminTests(TestCase):
    def setUp(self):
        self.admin = CustomUser.objects.create_user(
            username="admin", password="testpass123"
        )
        self.member = CustomUser.objects.create_user(
            username="member", password="testpass123"
        )
        self.team = Team.objects.create(name="Team", created_by=self.admin)
        add_team_member(self.team, self.admin, role="admin")
        add_team_member(self.team, self.member, role="member")

    def test_admin_is_admin(self):
        self.assertTrue(is_team_admin(self.admin, self.team))

    def test_member_is_not_admin(self):
        self.assertFalse(is_team_admin(self.member, self.team))


class ShareScheduleWithUserTests(TestCase):
    def setUp(self):
        self.owner = CustomUser.objects.create_user(
            username="owner", password="testpass123"
        )
        self.target = CustomUser.objects.create_user(
            username="target", password="testpass123"
        )
        self.schedule = Schedule.objects.create(name="Test", owner=self.owner)

    def test_share_creates_share(self):
        share = share_schedule_with_user(self.schedule, self.target, "view")
        self.assertEqual(share.permission, "view")

    def test_duplicate_share_raises(self):
        share_schedule_with_user(self.schedule, self.target, "view")
        with self.assertRaises(ValidationError):
            share_schedule_with_user(self.schedule, self.target, "edit")


class ShareScheduleWithTeamTests(TestCase):
    def setUp(self):
        self.owner = CustomUser.objects.create_user(
            username="owner", password="testpass123"
        )
        self.team = Team.objects.create(name="Team", created_by=self.owner)
        self.schedule = Schedule.objects.create(name="Test", owner=self.owner)

    def test_share_with_team(self):
        share = share_schedule_with_team(self.schedule, self.team, "edit")
        self.assertEqual(share.permission, "edit")

    def test_duplicate_team_share_raises(self):
        share_schedule_with_team(self.schedule, self.team, "view")
        with self.assertRaises(ValidationError):
            share_schedule_with_team(self.schedule, self.team, "edit")


class GetTeamsForUserTests(TestCase):
    def setUp(self):
        self.user = CustomUser.objects.create_user(
            username="user", password="testpass123"
        )
        self.team = Team.objects.create(name="Team", created_by=self.user)
        add_team_member(self.team, self.user, role="admin")

    def test_user_sees_their_teams(self):
        teams = get_teams_for_user(self.user)
        self.assertIn(self.team, teams)

    def test_unrelated_user_sees_no_teams(self):
        other = CustomUser.objects.create_user(username="other", password="testpass123")
        teams = get_teams_for_user(other)
        self.assertNotIn(self.team, teams)
