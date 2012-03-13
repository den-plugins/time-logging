$(document).ready(function(){
  initializers();
  Week.init();
});

/*
  $.getJSON('/week_logs.json', function(data) {
    console.log(data.issues.project_issues)
  });
*/
function initializers() {
  $(".hidden").hide();
  var date = new Date();
  var currentMonth = date.getMonth();
  var currentDate = date.getDate();
  var currentYear = date.getFullYear();
  
  if (typeof Week === 'undefined') {
    Week = {};
  }
  
  Week.init = function() {
    var current_date = new Date();
    var start;
    var end;
    $('#week_selector').datepicker({
      maxDate: new Date(currentYear, currentMonth, currentDate),
      showOn: "button",
      buttonImage: "",
      firstDay: 1,
      onSelect: function(select_date) {
        var date = $(this).datepicker('getDate');
        var maxDate = new Date(currentYear, currentMonth, currentDate);
        start = new Date(date.getFullYear(), date.getMonth(), date.getDate() - date.getDay()+1);
        end = new Date(date.getFullYear(), date.getMonth(), date.getDate() - date.getDay() + 7);
        if(end > maxDate)
          end = maxDate;
        var start_output = start.getDate()+"/"+(start.getMonth()+1)+"/"+start.getFullYear();
        var end_output = end.getDate()+"/"+(end.getMonth()+1)+"/"+end.getFullYear();
        $('#week_start').val(start_output);
        $('#week_end').val(end_output);
        $('#week_selector').val(start_output+" to "+end_output);
      },
      beforeShowDay: function(date) {
          var cssClass = '';
          if(date >= start && date <= end)
              cssClass = 'ui-state-active';
          return [true, cssClass];
      },
    });
  };
}
