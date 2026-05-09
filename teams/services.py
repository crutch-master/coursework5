from django.core.exceptions import ValidationError
from django.db.models import Q

from teams.models import Team, TeamMembership, ScheduleShare


def is_team_admin(user, team):
    return TeamMembership.objects.filter(user=user, team=team, role="admin").exists()


def add_team_member(team, user, role="member"):
    return TeamMembership.objects.create(user=user, team=team, role=role)


def remove_team_member(team, user):
    TeamMembership.objects.filter(user=user, team=team).delete()


def share_schedule_with_user(schedule, user, permission="view"):
    if ScheduleShare.objects.filter(
        schedule=schedule, shared_with_user=user, shared_with_team__isnull=True
    ).exists():
        raise ValidationError("This schedule is already shared with this user.")
    return ScheduleShare.objects.create(
        schedule=schedule, shared_with_user=user, permission=permission
    )


def share_schedule_with_team(schedule, team, permission="view"):
    if ScheduleShare.objects.filter(
        schedule=schedule, shared_with_team=team, shared_with_user__isnull=True
    ).exists():
        raise ValidationError("This schedule is already shared with this team.")
    return ScheduleShare.objects.create(
        schedule=schedule, shared_with_team=team, permission=permission
    )


def get_teams_for_user(user):
    return Team.objects.filter(
        Q(created_by=user) | Q(memberships__user=user)
    ).distinct()
