bootbox.alert("<%= @msg %>");

<% if @window_reload %>
  window.location.reload();
<% end %>