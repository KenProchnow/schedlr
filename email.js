var 
	email	= require('emailjs')
	, emailconfig = require('./lib/config/email.js')
	, fs = require('fs')
	, path = require('path')
	, server 			= email.server.connect(emailconfig)
	, distro 			= require('./lib/emailDistributionList/distributionList.js')
	, data = ''
	, fileDir 		= './../csv'
	;

var email = function(file){
	readData(file);
};

var readData = function(file) {
  var fileStream        = fs.createReadStream(path.join(fileDir, file + '.csv'));
  fileStream.on('data', function(chunk) { data+=chunk; });
  fileStream.on('end', function(){
    generateTable(data, file, function(table){
    	composeEmailHTML(table, file);
    });
  });
};

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

var isDate = function(date) {
	return (new Date(date) !== "Invalid Date" && !isNaN(new Date(date)) ) ? true : false;
};

var formatDate = function(date) {
	return new Date(date).toISOString().slice(0,10);
};

var hasDecimalString = function(number){
	var regex = /%/
	return regex.test(number) ;
};

var generateTable = function(data, file, cb) {
	var lines = data.split("\n"),
		table = [];

	for (var i = 0; i < lines.length; i++) {
		if (i === 0) { // headers
	    table.push('<tr><th>'+ lines[i].split(",").join('</th><th>')+ '</th></tr>');
		} else { // data
			line = lines[i].split(",");

			// Format Numbers
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

	cb(table, file);
};


var composeEmailHTML = function(table, file){
	var arr = ['You are receiving an automated message', // body
		distro[file], // distro
		'Data ready: '+file, // subject
		file+'.csv' // attachment
	];

	var text = arr[0], to = arr[1], subject = arr[2], attachment = arr[3];
	var message = {
		text: text,
		from: 'John Skilbeck jskilbeck@yapstone.com',
		to: 	to,
		subject: subject,
		attachment: [
			{ data: '<html><body><p>Automated Email</p><br />'+table+'</body></html>', alternative:true},
			{ path: path.join(fileDir,attachment), type: 'text/csv', name: attachment	}
		]
	};

	sendEmail(message);
};

var sendEmail = function(message){
	server.send(message, function(err, message){
		console.log(err || message);
	});
};

exports.email = email;


