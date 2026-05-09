from django.urls import path

from teams.views import (
    ScheduleShareCreateView,
    ScheduleShareDeleteView,
    TeamAddMemberView,
    TeamCreateView,
    TeamDeleteView,
    TeamDetailView,
    TeamListView,
    TeamRemoveMemberView,
    TeamUpdateView,
)

app_name = "teams"

urlpatterns = [
    path("", TeamListView.as_view(), name="team-list"),
    path("create/", TeamCreateView.as_view(), name="team-create"),
    path("<int:pk>/", TeamDetailView.as_view(), name="team-detail"),
    path("<int:pk>/update/", TeamUpdateView.as_view(), name="team-update"),
    path("<int:pk>/delete/", TeamDeleteView.as_view(), name="team-delete"),
    path("<int:pk>/members/add/", TeamAddMemberView.as_view(), name="team-add-member"),
    path(
        "<int:pk>/members/<int:user_pk>/remove/",
        TeamRemoveMemberView.as_view(),
        name="team-remove-member",
    ),
    path(
        "shares/create/",
        ScheduleShareCreateView.as_view(),
        name="schedule-share-create",
    ),
    path(
        "shares/<int:pk>/delete/",
        ScheduleShareDeleteView.as_view(),
        name="schedule-share-delete",
    ),
]
