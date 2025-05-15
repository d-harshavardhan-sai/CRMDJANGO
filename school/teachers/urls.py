from django.urls import path
from . import views

urlpatterns = [
    path('', views.teacher_list, name='all-teachers'),
    path('add-teacher/', views.add_teacher, name='addteacher'),
    path('update/<str:id>', views.update_teacher, name='update'),
    path('delete/<str:id>', views.delete_teacher, name='delete')
]