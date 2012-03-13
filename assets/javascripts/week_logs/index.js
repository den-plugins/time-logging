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
    var start = new Date(current_date.getFullYear(), current_date.getMonth(), current_date.getDate() - current_date.getDay()+1);
    var end = current_date;
    var start_output = start.getDate()+"/"+(start.getMonth()+1)+"/"+start.getFullYear();
    var end_output = end.getDate()+"/"+(end.getMonth()+1)+"/"+end.getFullYear();
    var maxDate = new Date(currentYear, currentMonth, currentDate);
    $('#week_start').val(start_output);
    $('#week_end').val(end_output);
    $('#week_selector').val(start_output+" to "+end_output);
    refreshTableDates();
    
    $('#week_selector').datepicker({
      maxDate: maxDate,
      showOn: "button",
      buttonImage: "",
      firstDay: 1,
      onSelect: function(select_date) {
        var date = $(this).datepicker('getDate');
        start = new Date(date.getFullYear(), date.getMonth(), date.getDate() - date.getDay()+1);
        end = new Date(date.getFullYear(), date.getMonth(), date.getDate() - date.getDay() + 7);
        if(end > maxDate)
          end = maxDate;
        start_output = start.getDate()+"/"+(start.getMonth()+1)+"/"+start.getFullYear();
        end_output = end.getDate()+"/"+(end.getMonth()+1)+"/"+end.getFullYear();
        $('#week_start').val(start_output);
        $('#week_end').val(end_output);
        $('#week_selector').val(start_output+" to "+end_output);
        refreshTableDates();
      },
      beforeShowDay: function(date) {
          var cssClass = '';
          if(date >= start && date <= end)
              cssClass = 'ui-state-highlight ui-state-active';
          return [true, cssClass];
      },
    });
    
    function refreshTableDates() {
      var inspect = start;
      var i = 0;
      var flag = false;
      var maxDate = new Date(inspect.getFullYear(), inspect.getMonth(), inspect.getDate() - inspect.getDay() + 7);
      while(inspect <= maxDate) {
        switch(i) {
          case 0:
              $("th.mon").html("Mon<br/>"+inspect.getDate());
              flag == true ? $(".mon").hide() : $(".mon").show()
            break;
          case 1:
              $("th.tue").html("Tue<br/>"+inspect.getDate());
              flag == true ? $(".tue").hide() : $(".tue").show()
            break;
          case 2:
              $("th.wed").html("Wed<br/>"+inspect.getDate());
              flag == true ? $(".wed").hide() : $(".wed").show()
            break;
          case 3:
              $("th.thu").html("Thu<br/>"+inspect.getDate());
              flag == true ? $(".thu").hide() : $(".thu").show()
            break;
          case 4:
              $("th.fri").html("Fri<br/>"+inspect.getDate());
              flag == true ? $(".fri").hide() : $(".fri").show()
            break;
          case 5:
              $("th.sat").html("Sat<br/>"+inspect.getDate());
              flag == true ? $(".sat").hide() : $(".sat").show()
            break;
          case 6:
              $("th.sun").html("Sun<br/>"+inspect.getDate());
              flag == true ? $(".sun").hide() : $(".sun").show()
            break;
        }
        if(inspect.toDateString() == end.toDateString())
          flag = true;
        i++;
        inspect.setDate(inspect.getDate()+1);
      }
    }
  };
}
