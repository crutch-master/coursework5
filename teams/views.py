from django.contrib.auth import get_user_model
from django.contrib.auth.mixins import LoginRequiredMixin
from django.contrib import messages
from django.core.exceptions import ValidationError
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse_lazy
from django.utils.decorators import method_decorator
from django.views import View
from django.views.decorators.http import require_POST
from django.views.generic import (
    CreateView,
    DeleteView,
    DetailView,
    ListView,
    UpdateView,
)

from schedules.models import Schedule
from teams.forms import ScheduleShareForm, TeamForm, TeamMembershipForm
from teams.models import ScheduleShare, Team, TeamMembership
from teams.services import (
    add_team_member,
    get_teams_for_user,
    is_team_admin,
    remove_team_member,
    share_schedule_with_team,
    share_schedule_with_user,
)

User = get_user_model()


class TeamListView(LoginRequiredMixin, ListView):
    model = Team
    template_name = "teams/team_list.html"

    def get_queryset(self):
        return get_teams_for_user(self.request.user)

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context["admin_team_ids"] = set(
            TeamMembership.objects.filter(
                user=self.request.user,
                role="admin",
                team__in=context["team_list"],
            ).values_list("team_id", flat=True)
        )
        return context


class TeamCreateView(LoginRequiredMixin, CreateView):
    model = Team
    form_class = TeamForm
    template_name = "teams/team_form.html"
    success_url = reverse_lazy("teams:team-list")

    def form_valid(self, form):
        form.instance.created_by = self.request.user
        response = super().form_valid(form)
        TeamMembership.objects.create(
            user=self.request.user, team=self.object, role="admin"
        )
        return response


class TeamDetailView(LoginRequiredMixin, DetailView):
    model = Team
    template_name = "teams/team_detail.html"

    def get_queryset(self):
        return get_teams_for_user(self.request.user)

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context["is_admin"] = is_team_admin(self.request.user, self.object)
        context["memberships"] = self.object.memberships.select_related("user").all()
        return context


class TeamUpdateView(LoginRequiredMixin, UpdateView):
    model = Team
    form_class = TeamForm
    template_name = "teams/team_form.html"

    def get_queryset(self):
        return Team.objects.filter(
            memberships__user=self.request.user, memberships__role="admin"
        )

    def get_success_url(self):
        return reverse_lazy("teams:team-detail", kwargs={"pk": self.object.pk})


class TeamDeleteView(LoginRequiredMixin, DeleteView):
    model = Team
    template_name = "teams/team_confirm_delete.html"
    success_url = reverse_lazy("teams:team-list")

    def get_queryset(self):
        return Team.objects.filter(
            memberships__user=self.request.user, memberships__role="admin"
        )


class TeamAddMemberView(LoginRequiredMixin, View):
    template_name = "teams/add_member.html"

    def get(self, request, pk):
        team = get_object_or_404(
            Team, pk=pk, memberships__user=request.user, memberships__role="admin"
        )
        form = TeamMembershipForm()
        return render(request, self.template_name, {"form": form, "team": team})

    def post(self, request, pk):
        team = get_object_or_404(
            Team, pk=pk, memberships__user=request.user, memberships__role="admin"
        )
        form = TeamMembershipForm(request.POST)
        if form.is_valid():
            add_team_member(team, form.cleaned_data["user"], form.cleaned_data["role"])
            return redirect("teams:team-detail", pk=team.pk)
        return render(request, self.template_name, {"form": form, "team": team})


@method_decorator(require_POST, name="dispatch")
class TeamRemoveMemberView(LoginRequiredMixin, View):
    def post(self, request, pk, user_pk):
        team = get_object_or_404(
            Team, pk=pk, memberships__user=request.user, memberships__role="admin"
        )
        user_to_remove = get_object_or_404(User, pk=user_pk)

        if request.user.pk == user_pk:
            admin_count = team.memberships.filter(role="admin").count()
            if admin_count <= 1:
                messages.error(
                    request,
                    "You cannot leave the team as the last admin. Promote another member first.",
                )
                return redirect("teams:team-detail", pk=team.pk)

        remove_team_member(team, user_to_remove)
        return redirect("teams:team-detail", pk=team.pk)


class ScheduleShareCreateView(LoginRequiredMixin, View):
    template_name = "teams/schedule_share_form.html"

    def get(self, request):
        initial = {}
        schedule_id = request.GET.get("schedule")
        if schedule_id:
            try:
                schedule = Schedule.objects.get(pk=schedule_id, owner=request.user)
                initial["schedule"] = schedule
            except Schedule.DoesNotExist:
                pass
        form = ScheduleShareForm(user=request.user, initial=initial)
        return render(request, self.template_name, {"form": form})

    def post(self, request):
        form = ScheduleShareForm(request.POST, user=request.user)
        if form.is_valid():
            share = form.save(commit=False)
            try:
                if share.shared_with_user:
                    share_schedule_with_user(
                        share.schedule, share.shared_with_user, share.permission
                    )
                elif share.shared_with_team:
                    share_schedule_with_team(
                        share.schedule, share.shared_with_team, share.permission
                    )
                return redirect("schedules:schedule-list")
            except ValidationError as e:
                form.add_error(None, e.message)
        return render(request, self.template_name, {"form": form})


class ScheduleShareDeleteView(LoginRequiredMixin, DeleteView):
    model = ScheduleShare
    template_name = "teams/schedule_share_confirm_delete.html"
    success_url = reverse_lazy("schedules:schedule-list")

    def get_queryset(self):
        return ScheduleShare.objects.filter(schedule__owner=self.request.user)
