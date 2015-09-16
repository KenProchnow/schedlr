var 
	email				= require('emailjs'),	
	emailconfig = require('./lib/config/email.js')
	, server 			= email.server.connect(emailconfig)
	, fs = require('fs')
	, path = require('path')
	, data = ''
	, fileDir 		= 'CSVs'
	;

var readData = function() {
	var file 		= fs.createReadStream(path.join(fileDir, file + '.csv'));

	file.on('data', function(chunk) { data+=chunk; });
};

var composeEmail = function(arr){
	var text = arr[0], to = arr[1], subject = arr[2], attachment = arr[3];
	var message = {
		text: text,
		from: 'John Skilbeck jskilbeck@yapstone.com',
		to: 	to,
		subject: subject,
		attachment: [
			{ path: 'CSVs/'+attachment, type: 'text/csv', name: attachment	}
		]
	};

	sendEmail(message);
};


var sendEmail = function(message){
	server.send(message, function(err, message){
		console.log(err || message);
	});
};

var email = function(arr){
	// readData();
	// file.on('end', function() {
		composeEmail(arr);
	// });

};

exports.email = email;


