from django.contrib.auth.mixins import LoginRequiredMixin
from django.contrib import messages
from django.db import transaction
from django.http import Http404, HttpResponseForbidden, JsonResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse_lazy
from django.views import View
from django.views.generic import (
    CreateView,
    DeleteView,
    DetailView,
    ListView,
    UpdateView,
)

from accounts.models import CustomUser
from schedules.forms import EventForm, RecurrenceRuleForm, ScheduleForm
from schedules.models import Event, EventParticipant, Schedule
from schedules.services import (
    create_event_with_checks,
    detect_conflicts,
    get_user_schedules,
    update_event_with_checks,
    user_can_edit_schedule,
    user_can_view_schedule,
)


class ScheduleListView(LoginRequiredMixin, ListView):
    model = Schedule
    template_name = "schedules/schedule_list.html"

    def get_queryset(self):
        return get_user_schedules(self.request.user)


class ScheduleCreateView(LoginRequiredMixin, CreateView):
    model = Schedule
    form_class = ScheduleForm
    template_name = "schedules/schedule_form.html"
    success_url = reverse_lazy("schedules:schedule-list")

    def form_valid(self, form):
        form.instance.owner = self.request.user
        return super().form_valid(form)


class ScheduleUpdateView(LoginRequiredMixin, UpdateView):
    model = Schedule
    form_class = ScheduleForm
    template_name = "schedules/schedule_form.html"

    def get_queryset(self):
        return Schedule.objects.filter(owner=self.request.user)

    def get_success_url(self):
        return reverse_lazy("schedules:schedule-list")


class ScheduleDeleteView(LoginRequiredMixin, DeleteView):
    model = Schedule
    template_name = "schedules/schedule_confirm_delete.html"
    success_url = reverse_lazy("schedules:schedule-list")

    def get_queryset(self):
        return Schedule.objects.filter(owner=self.request.user)


class ScheduleCalendarView(LoginRequiredMixin, DetailView):
    model = Schedule
    template_name = "schedules/schedule_calendar.html"

    def get_queryset(self):
        return get_user_schedules(self.request.user)

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        if self.object.owner == self.request.user:
            context["shares"] = self.object.shares.select_related(
                "shared_with_user", "shared_with_team"
            ).all()
        context["can_edit"] = user_can_edit_schedule(self.request.user, self.object)
        return context


class ScheduleCalendarJSONView(LoginRequiredMixin, View):
    def get(self, request, pk):
        schedule = get_object_or_404(get_user_schedules(request.user), pk=pk)
        start = request.GET.get("start")
        end = request.GET.get("end")
        events = schedule.events.select_related("schedule").all()
        if start and end:
            events = events.filter(
                start_datetime__lt=end,
                end_datetime__gt=start,
            )
        return JsonResponse([e.to_calendar_dict() for e in events], safe=False)


class EventDetailView(LoginRequiredMixin, DetailView):
    model = Event
    template_name = "schedules/event_detail.html"

    def get_queryset(self):
        return Event.objects.filter(
            schedule__in=get_user_schedules(self.request.user)
        ).prefetch_related("participants__user")

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context["can_edit"] = user_can_edit_schedule(
            self.request.user, self.object.schedule
        )
        return context


class EventCreateView(LoginRequiredMixin, View):
    template_name = "schedules/event_form.html"

    def get(self, request, schedule_pk):
        schedule = get_object_or_404(get_user_schedules(request.user), pk=schedule_pk)
        if not user_can_edit_schedule(request.user, schedule):
            return HttpResponseForbidden(
                "You do not have edit permission for this schedule."
            )
        form = EventForm(schedule=schedule)
        recurrence_form = RecurrenceRuleForm()
        return render(
            request,
            self.template_name,
            {
                "form": form,
                "recurrence_form": recurrence_form,
                "schedule": schedule,
            },
        )

    @transaction.atomic
    def post(self, request, schedule_pk):
        schedule = get_object_or_404(get_user_schedules(request.user), pk=schedule_pk)
        if not user_can_edit_schedule(request.user, schedule):
            return HttpResponseForbidden(
                "You do not have edit permission for this schedule."
            )
        form = EventForm(request.POST, schedule=schedule)
        recurrence_form = RecurrenceRuleForm(request.POST)

        participant_emails = [
            e.strip()
            for e in request.POST.get("participant_emails", "").splitlines()
            if e.strip()
        ]
        participant_users = list(
            CustomUser.objects.filter(email__in=participant_emails)
        )
        found_emails = {u.email for u in participant_users}
        missing_emails = [e for e in participant_emails if e not in found_emails]

        if form.is_valid():
            event_data = form.cleaned_data
            event_data.pop("participant_emails", None)
            event_data["schedule"] = schedule
            if recurrence_form.is_valid() and recurrence_form.cleaned_data.get(
                "frequency"
            ):
                rule = recurrence_form.save()
                event_data["recurrence"] = rule
            else:
                event_data["recurrence"] = None
            conflicts = detect_conflicts(
                request.user,
                event_data["start_datetime"],
                event_data["end_datetime"],
            )
            if conflicts:
                form.add_error(
                    None,
                    f"This event conflicts with: {', '.join(c.title for c in conflicts)}",
                )
            else:
                event = create_event_with_checks(
                    event_data, participant_users, request.user
                )
                if missing_emails:
                    messages.warning(
                        request, f"No accounts found for: {', '.join(missing_emails)}"
                    )
                return redirect("schedules:event-detail", pk=event.pk)
            if event_data.get("recurrence") and event_data["recurrence"].pk:
                event_data["recurrence"].delete()

        return render(
            request,
            self.template_name,
            {
                "form": form,
                "recurrence_form": recurrence_form,
                "schedule": schedule,
            },
        )


class EventUpdateView(LoginRequiredMixin, View):
    template_name = "schedules/event_form.html"

    def get(self, request, pk):
        event = get_object_or_404(
            Event.objects.select_related("schedule"),
            pk=pk,
            schedule__in=get_user_schedules(request.user),
        )
        if not user_can_edit_schedule(request.user, event.schedule):
            return HttpResponseForbidden(
                "You do not have edit permission for this schedule."
            )
        form = EventForm(instance=event, schedule=event.schedule)
        recurrence_form = RecurrenceRuleForm(instance=event.recurrence)
        participant_emails = "\n".join(
            event.participants.values_list("user__email", flat=True)
        )
        return render(
            request,
            self.template_name,
            {
                "form": form,
                "recurrence_form": recurrence_form,
                "schedule": event.schedule,
                "event": event,
                "participant_emails": participant_emails,
            },
        )

    @transaction.atomic
    def post(self, request, pk):
        event = get_object_or_404(
            Event.objects.select_related("schedule"),
            pk=pk,
            schedule__in=get_user_schedules(request.user),
        )
        if not user_can_edit_schedule(request.user, event.schedule):
            return HttpResponseForbidden(
                "You do not have edit permission for this schedule."
            )
        form = EventForm(request.POST, instance=event, schedule=event.schedule)
        recurrence_form = RecurrenceRuleForm(request.POST, instance=event.recurrence)

        participant_emails = [
            e.strip()
            for e in request.POST.get("participant_emails", "").splitlines()
            if e.strip()
        ]
        participant_users = list(
            CustomUser.objects.filter(email__in=participant_emails)
        )

        if form.is_valid():
            cleaned = form.cleaned_data
            cleaned.pop("participant_emails", None)
            if recurrence_form.is_valid() and recurrence_form.cleaned_data.get(
                "frequency"
            ):
                rule = recurrence_form.save()
                cleaned["recurrence"] = rule
            else:
                cleaned["recurrence"] = None
            update_event_with_checks(event, cleaned, participant_users)
            return redirect("schedules:event-detail", pk=event.pk)

        return render(
            request,
            self.template_name,
            {
                "form": form,
                "recurrence_form": recurrence_form,
                "schedule": event.schedule,
                "event": event,
            },
        )


class EventDeleteView(LoginRequiredMixin, DeleteView):
    model = Event
    template_name = "schedules/event_confirm_delete.html"

    def get_queryset(self):
        return Event.objects.select_related("schedule").filter(
            schedule__in=get_user_schedules(self.request.user)
        )

    def get_success_url(self):
        return reverse_lazy(
            "schedules:schedule-calendar", kwargs={"pk": self.object.schedule.pk}
        )

    def form_valid(self, form):
        if not user_can_edit_schedule(self.request.user, self.object.schedule):
            return HttpResponseForbidden(
                "You do not have edit permission for this schedule."
            )
        return super().form_valid(form)


class EventRSVPView(LoginRequiredMixin, View):
    def post(self, request, pk):
        event = get_object_or_404(Event, pk=pk)
        if not user_can_view_schedule(request.user, event.schedule):
            raise Http404
        participant = EventParticipant.objects.filter(
            user=request.user, event=event
        ).first()
        if not participant:
            messages.error(request, "You are not a participant of this event.")
            return redirect("schedules:event-detail", pk=event.pk)

        rsvp_status = request.POST.get("rsvp_status")
        if rsvp_status not in dict(EventParticipant.RSVP_CHOICES):
            messages.error(request, "Invalid RSVP status.")
            return redirect("schedules:event-detail", pk=event.pk)

        participant.rsvp_status = rsvp_status
        participant.save()
        return redirect("schedules:event-detail", pk=event.pk)
