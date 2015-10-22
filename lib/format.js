var 
	fs = require('fs')
	, path = require('path')
	, csv = require('fast-csv')
	, data = ''
	, fileDir = './../csv'
	;

/* Is/Boolean Function */
var isDate = function(date) {
	return (new Date(date) !== "Invalid Date"  && ( hasDay(date) ) && ( !isYear(date) ) && (	!isMonth(date) ) && !isNaN(new Date(date)) ) ? true : false;
};

var hasDay = function(date){
	var re = /((sun)|(mon)|(tue)|(wed)|(thu)|(fri)|(sat))/i;

	return re.test(date) ? true : false;
};

var isYear = function(date){
	var re = /^((2009)|(2010)|(2011)|(2012)|(2013)|(2014)|(2015)|(2016)|(2017))$/i;

	return re.test(date) ? true : false;
};

var isMonth = function(date){
	var re = /^((1)|(2)|(3)|(4)|(5)|(6)|(7)|(8)|(9)|(10)|(11)|(12)|(01)|(02)|(03)|(04)|(05)|(06)|(07)|(08)|(09)|(10)|(11)|(12))$/i;

	return re.test(date) ? true : false;
};

var hasPercentString = function(number){
	var regex = /%/;
	return regex.test(number) ;
};

var isDateColumn = function(item) {
	re = /^((Year)|(Month)|(Date)|(Year_First)|(Year_Last)|(12MonthsBeforeAttrited)|(DateFirstSeen)|(DateLastSeen))$/i;

	return re.test(item) ? true : false;
};

var isExcludeColumn = function(item){
	re = /^((AccountId)|(ParentAccountId)|(ChildAccountId)|(ChildName)|(ParentName))$/;

	return re.test(item) ? true	: false;
};

/* Format Functions */
var formatNumber = function (number){
	var number = number.toFixed(2) + '';
	var x = number.split('.');
	var x1 = x[0];
	var x2 = x.length > 1 ? '.' + x[1] : '';
	var rgx = /(\d+)(\d{3})/;
	while (rgx.test(x1)) {
	x1 = x1.replace(rgx, '$1' + ',' + '$2');
	}
	return x1;
};

var formatDate = function(date) {
	return new Date(date).toISOString().slice(0,10);
};

/* Table Functions */
var generateTableJSON = function(data, folder, file, cb){
	var table = [];

	// headers
	for(var record in data){
		if (data.hasOwnProperty(record)){ // data[record] logs records
			for(var item in data[record]){
				if(data[record].hasOwnProperty(item)){ // (key)item : (values)data[record][item] 
					table.push('<th align="center">'+item+'</td>');
				}
			}
			table.push('</tr>');
			break;
		}
	}

	// data
	for(var record in data){
		if (data.hasOwnProperty(record)){ // data[record] logs records
			table.push('<tr>');
			for(var item in data[record]){
				if(data[record].hasOwnProperty(item)){ // console.log(data[record][item]);  // logs Values // console.log(item); // logs keys
					table.push('<td align="center">'+data[record][item]+'</td>');
				}
			}
			table.push('</tr>');
		}
	}
	table = '<table border="2" cellspacing="1" cellpadding="2">'+table.join('')+'</table>';

	cb(table, folder, file);
};

var generateTable = function(data, folder, file, cb) {
	var lines = data.split("\n"),
		table = [];

	for (var i = 0; i < lines.length; i++) {
		if (i === 0) { // headers
	    table.push('<tr><th>'+ lines[i].split(",").join('</th><th>')+ '</th></tr>');
		} else { // data
			line = lines[i].split(",");
			line.map(function(item, index){
				if ( !isNaN(parseFloat(item)) && !hasDecimalString(item) ) {
					return line[index] = formatNumber(parseInt(item));
				} else if ( isDate(item) && !hasDecimalString(item) ) {
					return line[index] = formatDate(item);
				}
			});

			table.push('<tr><td align="center">'+ line.join('</td><td align="center">')+ '</td></tr>');
		}
	}
	table = '<table border="2" cellspcing="1" cellpadding="1">' + table.join("") + '</table>';

	cb(table, folder, file);
};

/* Is Functions */
exports.isDateColumn = isDateColumn;
exports.isExcludeColumn = isExcludeColumn;
exports.isDate = isDate;
exports.hasPercentString = hasPercentString;

/* Format Functions */
exports.formatDate = formatDate;
exports.formatNumber = formatNumber;

/* Table Functions */
exports.generateTableJSON = generateTableJSON;
