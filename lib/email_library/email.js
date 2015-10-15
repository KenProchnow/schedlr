var 
	email				= require('emailjs'),
	emailconfig = require('./../config/email.js'),
	server 			= email.server.connect(emailconfig),
	distro 	= require('./../distribution.js'),
	fs = require('fs'),
	path = require('path'),
	data = '',
	fileDir 		= './../csv'
	;

var email = function(data,file, cb){
	composeEmail(file, function(message){
		sendEmail(message);
	});
};

var composeEmail = function(file, cb){
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


