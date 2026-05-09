from django import template

register = template.Library()


@register.filter(name="bootstrap")
def bootstrap(field):
    if field.field.widget.__class__.__name__ in ("Select", "SelectMultiple"):
        css = "form-select"
    elif field.field.widget.__class__.__name__ in ("CheckboxInput",):
        css = "form-check-input"
    else:
        css = "form-control"
    return field.as_widget(attrs={"class": css})
