define([],

function() {
   return {
       diff : function(a1, a2) {
           return a1.filter(function(i) {return !(a2.indexOf(i) > -1);});
       }
   }
});