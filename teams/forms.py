from django import forms
from django.contrib.auth import get_user_model

from schedules.models import Schedule
from teams.models import Team, TeamMembership, ScheduleShare

User = get_user_model()


class TeamForm(forms.ModelForm):
    class Meta:
        model = Team
        fields = ["name", "description"]
        widgets = {
            "description": forms.Textarea(attrs={"rows": 3}),
        }


class TeamMembershipForm(forms.ModelForm):
    class Meta:
        model = TeamMembership
        fields = ["user", "role"]
        widgets = {
            "role": forms.Select(attrs={"class": "form-select"}),
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["user"].queryset = User.objects.all()


class ScheduleShareForm(forms.ModelForm):
    class Meta:
        model = ScheduleShare
        fields = ["schedule", "shared_with_user", "shared_with_team", "permission"]
        widgets = {
            "schedule": forms.Select(attrs={"class": "form-select"}),
            "permission": forms.Select(attrs={"class": "form-select"}),
        }

    def __init__(self, *args, **kwargs):
        self.user = kwargs.pop("user", None)
        super().__init__(*args, **kwargs)
        if self.user:
            self.fields["schedule"].queryset = Schedule.objects.filter(owner=self.user)
