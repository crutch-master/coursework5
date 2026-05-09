from django import forms

from schedules.models import Schedule, Event, RecurrenceRule


class ScheduleForm(forms.ModelForm):
    class Meta:
        model = Schedule
        fields = ["name", "description", "color"]
        widgets = {
            "description": forms.Textarea(attrs={"rows": 3}),
        }


class RecurrenceRuleForm(forms.ModelForm):
    class Meta:
        model = RecurrenceRule
        fields = ["frequency", "interval", "end_date", "days_of_week"]
        widgets = {
            "end_date": forms.DateInput(attrs={"type": "date"}),
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["frequency"].required = False
        self.fields["end_date"].required = False
        self.fields["days_of_week"].required = False

    def save(self, commit=True):
        if not self.cleaned_data.get("frequency"):
            return None
        return super().save(commit=commit)

    def clean(self):
        cleaned = super().clean()
        if cleaned.get("frequency") == "weekly" and not cleaned.get("days_of_week"):
            raise forms.ValidationError(
                "Weekly recurrence requires selecting days of the week."
            )
        return cleaned


class EventForm(forms.ModelForm):
    participant_emails = forms.CharField(
        required=False,
        widget=forms.Textarea(
            attrs={
                "rows": 2,
                "placeholder": "Enter email addresses, one per line",
                "class": "form-control",
            }
        ),
        help_text="Enter email addresses of participants, one per line",
    )

    class Meta:
        model = Event
        fields = [
            "title",
            "description",
            "start_datetime",
            "end_datetime",
            "location",
            "is_all_day",
        ]
        widgets = {
            "start_datetime": forms.DateTimeInput(attrs={"type": "datetime-local"}),
            "end_datetime": forms.DateTimeInput(attrs={"type": "datetime-local"}),
            "description": forms.Textarea(attrs={"rows": 3}),
        }

    def __init__(self, *args, **kwargs):
        self.schedule = kwargs.pop("schedule", None)
        super().__init__(*args, **kwargs)
