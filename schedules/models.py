from django.core.exceptions import ValidationError
from django.core.validators import RegexValidator
from django.db import models
from django.conf import settings


class Schedule(models.Model):
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    color = models.CharField(
        max_length=7,
        default="#3788d8",
        validators=[
            RegexValidator(
                r"^#[0-9a-fA-F]{6}$", "Enter a valid hex color, e.g. #3788d8"
            )
        ],
    )
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="schedules"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class RecurrenceRule(models.Model):
    FREQUENCY_CHOICES = [
        ("daily", "Daily"),
        ("weekly", "Weekly"),
        ("monthly", "Monthly"),
        ("yearly", "Yearly"),
    ]

    frequency = models.CharField(max_length=10, choices=FREQUENCY_CHOICES)
    interval = models.PositiveIntegerField(default=1)
    end_date = models.DateField(null=True, blank=True)
    days_of_week = models.CharField(
        max_length=20,
        blank=True,
        validators=[
            RegexValidator(
                r"^(MO|TU|WE|TH|FR|SA|SU)(,(MO|TU|WE|TH|FR|SA|SU))*$",
                "Enter valid day abbreviations separated by commas (e.g. MO,TU,WE).",
            )
        ],
    )

    def __str__(self):
        parts = [f"Every {self.interval} {self.frequency}"]
        if self.days_of_week:
            parts.append(f"on {self.days_of_week}")
        if self.end_date:
            parts.append(f"until {self.end_date}")
        return " ".join(parts)


class Event(models.Model):
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    start_datetime = models.DateTimeField()
    end_datetime = models.DateTimeField()
    location = models.CharField(max_length=300, blank=True)
    schedule = models.ForeignKey(
        Schedule, on_delete=models.CASCADE, related_name="events"
    )
    creator = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="created_events",
    )
    is_all_day = models.BooleanField(default=False)
    recurrence = models.ForeignKey(
        RecurrenceRule,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="events",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["start_datetime"]

    def __str__(self):
        return self.title

    def clean(self):
        super().clean()
        if (
            self.end_datetime
            and self.start_datetime
            and self.end_datetime <= self.start_datetime
        ):
            raise ValidationError(
                {"end_datetime": "End datetime must be after start datetime."}
            )

    def to_calendar_dict(self):
        from django.urls import reverse

        return {
            "id": self.pk,
            "title": self.title,
            "start": self.start_datetime.isoformat(),
            "end": self.end_datetime.isoformat(),
            "allDay": self.is_all_day,
            "color": self.schedule.color,
            "url": reverse("schedules:event-detail", kwargs={"pk": self.pk}),
        }


class EventParticipant(models.Model):
    RSVP_CHOICES = [
        ("pending", "Pending"),
        ("accepted", "Accepted"),
        ("declined", "Declined"),
        ("tentative", "Tentative"),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="event_participations",
    )
    event = models.ForeignKey(
        Event, on_delete=models.CASCADE, related_name="participants"
    )
    rsvp_status = models.CharField(
        max_length=10, choices=RSVP_CHOICES, default="pending"
    )

    class Meta:
        unique_together = ["user", "event"]

    def __str__(self):
        return f"{self.user} - {self.event} ({self.rsvp_status})"
