var 
	email	= require('emailjs')
	, emailconfig = require('./lib/config/email.js')
	, fs = require('fs')
	, path = require('path')
	, server 			= email.server.connect(emailconfig)
	, distro 			= './lib/emailDistributionList/distributionList.js'
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

var generateTable = function(data, file, cb) {
	var lines = data.split("\n"),
		table = [];

	for (var i = 0; i < lines.length; i++) {
		if (i === 0) { // headers
	    table.push('<tr><th>'+ lines[i].split(",").join('</th><th>')+ '</th></tr>');
		} else { // data
			table.push('<tr><td align="center">'+ lines[i].split(",").join('</td><td align="center">')+ '</td></tr>');
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
		to: 	'jskilbeck@yapstone.com',
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


