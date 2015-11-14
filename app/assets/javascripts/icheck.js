/**
* Icheck module
**/
var Icheck = {
  /**
  * Init
  **/
  init: function(div){
    var self = this;

    this.styles = {
      'minimal': [
          null,
          'aero',
          'blue',
          'green',
          'grey',
          'orange',
          'pink',
          'purple',
          'red',
          'yellow'
      ],
      'square': [
          null,
          'aero',
          'blue',
          'green',
          'grey',
          'orange',
          'pink',
          'purple',
          'red',
          'yellow'
      ]
    };
    
    self.init_icheck(div);
  },

  /**
  * Init Icheck
  **/
  init_icheck: function(div){
    if( ie < Proceduresync.OLD_IE_VERSION ){
      return;
    }

    var self = this;

    var j, name, cl, style;
    if(typeof div == "undefined"){
      var $ichecks = $('input.icheck');
    }else{
      var $ichecks = div.find("input.icheck");
    }

    for (name in self.styles) {
      style = self.styles[name];
      for (j = 0; j < style.length; j++) {
        cl = name;
        if (style[j]) cl += '-' + style[j];

        if (name == 'line') {
          $ichecks.filter('.' + cl).each(function(){
            self.iCheckLine(this);
          });
        } else {
          $ichecks.filter('.' + cl).iCheck({
              checkboxClass: 'icheckbox_' + cl,
              radioClass: 'iradio_' + cl
          });
        }
      }
    }
  },

  iCheckLine: function(ele) {
    var self = $(ele);
    var label = self.parent().text();

    self.parent().empty().append(self);

    self.iCheck({
        checkboxClass: 'icheckbox_' + cl,
        radioClass: 'iradio_' + cl,
        insert: '<div class="icheck_line-icon"></div>' + label
    });
  }
}

$(function() {
  Icheck.init();
});