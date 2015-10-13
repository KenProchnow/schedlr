var 
	fs = require('fs')
	, path = require('path')
	, email	= require('emailjs')
	, emailconfig = require('./lib/config/email.js')
	, distro 	= require('./lib/distribution.js')
	, f = require('./lib/format.js')
	, server 	= email.server.connect(emailconfig)
	, fileDir = './../csv'
	;

var email = function(data, file){
	f.generateTableJSON(data, file, function(table){
		composeEmail(table, file, function(message){
			sendEmail(message);
		});
	});
};

var composeEmail = function(table, file, cb){
	var now = new Date();
	var arr = ['Automated report generated on: '+now.toString().slice(0,21), // body
		distro[file], // distro
		file +' : Yapstone BI Reports', // subject
		file+'.csv' // attachment
	];

	var text = arr[0], to = arr[1], subject = arr[2], attachment = arr[3];

	var message = {
		text: text,
		from: 'John Skilbeck jskilbeck@yapstone.com',
		to: 	to,
		subject: subject,
		attachment: [
			{ data: '<html><body><p>'+text+'</p><br />'+table+'</body></html>', alternative:true},
			{ path: path.join(fileDir,attachment), type: 'text/csv', name: attachment	}
		]
	};

	cb(message);
};

var sendEmail = function(message){
	server.send(message, function(err, message){
		console.log(err || message);
	});
};

exports.email = email;


