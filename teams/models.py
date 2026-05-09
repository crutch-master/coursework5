from django.core.exceptions import ValidationError
from django.db import models
from django.conf import settings

from schedules.models import Schedule


class Team(models.Model):
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="created_teams"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class TeamMembership(models.Model):
    ROLE_CHOICES = [
        ("admin", "Admin"),
        ("member", "Member"),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="team_memberships",
    )
    team = models.ForeignKey(Team, on_delete=models.CASCADE, related_name="memberships")
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default="member")

    class Meta:
        unique_together = ["user", "team"]

    def __str__(self):
        return f"{self.user} - {self.team} ({self.role})"


class ScheduleShare(models.Model):
    PERMISSION_CHOICES = [
        ("view", "View"),
        ("edit", "Edit"),
    ]

    schedule = models.ForeignKey(
        Schedule, on_delete=models.CASCADE, related_name="shares"
    )
    shared_with_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="shared_schedules",
    )
    shared_with_team = models.ForeignKey(
        Team,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="shared_schedules",
    )
    permission = models.CharField(
        max_length=10, choices=PERMISSION_CHOICES, default="view"
    )

    class Meta:
        unique_together = ["schedule", "shared_with_user", "shared_with_team"]

    def __str__(self):
        target = self.shared_with_user or self.shared_with_team
        return f"{self.schedule} shared with {target} ({self.permission})"

    def clean(self):
        super().clean()
        has_user = self.shared_with_user_id is not None
        has_team = self.shared_with_team_id is not None
        if has_user and has_team:
            raise ValidationError(
                "A share must target either a user or a team, not both."
            )
        if not has_user and not has_team:
            raise ValidationError("A share must target a user or a team.")

        qs = ScheduleShare.objects.filter(schedule=self.schedule)
        if has_user:
            qs = qs.filter(
                shared_with_user=self.shared_with_user, shared_with_team__isnull=True
            )
        elif has_team:
            qs = qs.filter(
                shared_with_team=self.shared_with_team, shared_with_user__isnull=True
            )
        if self.pk:
            qs = qs.exclude(pk=self.pk)
        if qs.exists():
            raise ValidationError("This schedule is already shared with this target.")
