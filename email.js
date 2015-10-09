var 
	fs = require('fs')
	, path = require('path')
	, email	= require('emailjs')
	, emailconfig = require('./lib/config/email.js')
	, distro 	= require('./lib/emailDistributionList/distributionList.js')
	, f = require('./lib/format.js')
	, server 	= email.server.connect(emailconfig)
	, data = ''
	, fileDir = './../csv'
	;

var email = function(file){
	readData(file, function(){
		f.generateTable(data, file, function(table){
			composeEmailHTML(table, file, function(message){
				// console.log(message);
				sendEmail(message);
			});
		});
	});
};

var readData = function(file, cb) {
	var fileStream        = fs.createReadStream(path.join(fileDir, file + '.csv'));
	fileStream.on('data', function(chunk) { data+=chunk; });
	fileStream.on('end', function(){
		cb()
	});
};

var composeEmailHTML = function(table, file, cb){
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

	cb(message);
};

var sendEmail = function(message){
	server.send(message, function(err, message){
		console.log(err || message);
	});
};

exports.email = email;


