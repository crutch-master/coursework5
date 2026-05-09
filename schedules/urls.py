from django.urls import path

from schedules.views import (
    EventCreateView,
    EventDeleteView,
    EventDetailView,
    EventRSVPView,
    EventUpdateView,
    ScheduleCalendarJSONView,
    ScheduleCalendarView,
    ScheduleCreateView,
    ScheduleDeleteView,
    ScheduleListView,
    ScheduleUpdateView,
)

app_name = "schedules"

urlpatterns = [
    path("", ScheduleListView.as_view(), name="schedule-list"),
    path("create/", ScheduleCreateView.as_view(), name="schedule-create"),
    path("<int:pk>/update/", ScheduleUpdateView.as_view(), name="schedule-update"),
    path("<int:pk>/delete/", ScheduleDeleteView.as_view(), name="schedule-delete"),
    path(
        "<int:pk>/calendar/", ScheduleCalendarView.as_view(), name="schedule-calendar"
    ),
    path(
        "<int:pk>/calendar/json/",
        ScheduleCalendarJSONView.as_view(),
        name="schedule-calendar-json",
    ),
    path("events/<int:pk>/", EventDetailView.as_view(), name="event-detail"),
    path(
        "<int:schedule_pk>/events/create/",
        EventCreateView.as_view(),
        name="event-create",
    ),
    path("events/<int:pk>/update/", EventUpdateView.as_view(), name="event-update"),
    path("events/<int:pk>/delete/", EventDeleteView.as_view(), name="event-delete"),
    path("events/<int:pk>/rsvp/", EventRSVPView.as_view(), name="event-rsvp"),
]
