from django.db import transaction
from django.db.models import Q

from schedules.models import Event, EventParticipant, Schedule
from teams.models import ScheduleShare


def detect_conflicts(user, start_datetime, end_datetime, exclude_event=None):
    events = Event.objects.filter(
        Q(participants__user=user) | Q(creator=user),
        start_datetime__lt=end_datetime,
        end_datetime__gt=start_datetime,
    )
    if exclude_event:
        events = events.exclude(pk=exclude_event.pk)
    return events.distinct()


@transaction.atomic
def create_event_with_checks(event_data, participant_users, creator):
    event = Event.objects.create(**event_data, creator=creator)
    for user in participant_users:
        EventParticipant.objects.create(user=user, event=event)
    return event


@transaction.atomic
def update_event_with_checks(event, cleaned_data, participant_users):
    old_recurrence = event.recurrence
    for attr, value in cleaned_data.items():
        setattr(event, attr, value)
    event.save()
    if old_recurrence and old_recurrence != event.recurrence:
        old_recurrence.delete()
    event.participants.exclude(user__in=participant_users).delete()
    existing_user_ids = set(event.participants.values_list("user_id", flat=True))
    for user in participant_users:
        if user.pk not in existing_user_ids:
            EventParticipant.objects.create(user=user, event=event)
    return event


def get_user_schedules(user):
    owned = Schedule.objects.filter(owner=user)
    shared_via_user = Schedule.objects.filter(shares__shared_with_user=user)
    shared_via_team = Schedule.objects.filter(
        shares__shared_with_team__memberships__user=user
    )
    return (owned | shared_via_user | shared_via_team).distinct()


def user_can_edit_schedule(user, schedule):
    if schedule.owner == user:
        return True
    return ScheduleShare.objects.filter(
        Q(shared_with_user=user) | Q(shared_with_team__memberships__user=user),
        schedule=schedule,
        permission="edit",
    ).exists()


def user_can_view_schedule(user, schedule):
    return get_user_schedules(user).filter(pk=schedule.pk).exists()
