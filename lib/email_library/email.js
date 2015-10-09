var 
	email				= require('emailjs'),
	emailconfig = require('./../config/email.js'),
	server 			= email.server.connect(emailconfig),
	distro 	= require('./../emailDistributionList/distributionList.js'),
	fs = require('fs'),
	path = require('path'),
	data = '',
	fileDir 		= './../csv'
	;

var email = function(file){
	composeEmail(file);
};

var composeEmail = function(file){
	var arr = ['You are receiving an automated message ',
		distro[file],
		'Data ready:'+file,
		file+'.csv'
		];

	var text = arr[0], to = arr[1], subject = arr[2], attachment = arr[3];

	var message = {
		text: text,
		from: 'John Skilbeck jskilbeck@yapstone.com',
		to: 	to,
		subject: subject,
		attachment: [
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


