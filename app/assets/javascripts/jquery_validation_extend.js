/**
* Add more methods to jQuery Validate
**/

jQuery.validator.addMethod("password_validation", function(value, element) {
  var AZ = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"];
  var az = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"];
  var digits = [ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"];

  var has_AZ = false;
  var has_az = false;
  var has_digits = false;

  value += "";

  if (value.length == 0){
    return true;
  }

  for (var i = 0; i < value.length; i++) {
    if( AZ.indexOf(value[i]) != -1){
      has_AZ = true;
    }else if( az.indexOf(value[i]) != -1){
      has_az = true;
    }else if( digits.indexOf(value[i]) != -1){
      has_digits = true;
    }
  };

  return (has_AZ && has_digits && has_az);

  //return this.optional(element) || /^http:\/\/mycorporatedomain.com/.test(value);
}, "Password is not strong, must to be mix of upper, lower, numbers, and min length is 10 chars");

/**
* Validate card expiry: MM/YYYY 
**/
$.validator.addMethod(
    "card_expiry",
    function(value, element) {
        // put your own logic here, this is just a (crappy) example
        return value.match(/^\d\d?\/\d\d\d\d$/);
    },
    "Please enter Expiry date in the format MM/YYYY."
);
