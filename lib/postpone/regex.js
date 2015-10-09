var text = 
'VRP,535.54,7453'+
'Wed Sep 23 2015 17:00:00 GMT-0700 (PDT),Dues,211.99,498';

var vrp = /VRP(.[0-9]+)/.exec(text);

console.log(vrp[1]);

var re1 = '.*?' 
	, re2 =	'([+-]?\\d*\\.\\d+)(?![-+0-9\\.])'
	;

var reg = new RegExp(re1+re2,["i"]);
var regx = /.*?([+-]?\d*\.\d+)(?![-+0-9\.])/i,
	 match = reg.exec(text)
;

// console.log(regx.exec(text));
// console.dir(reg);

// console.log(regx.exec(text)[1])