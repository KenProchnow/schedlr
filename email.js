var 
	email				= require('emailjs'),
	emailconfig = require('./lib/config/email.js'),
	server 			= email.server.connect(emailconfig),
	fs = require('fs'),
	path = require('path'),
	data = '',
	fileDir 		= 'CSVs'
	;

// var arr = ['You are receiving an automated message', // body
// 		distro[file], // distro
// 		'Daily TPV numbers', // subject
// 		file+'.csv' // attachment
// 	];

var email = function(arr){
	composeEmail(arr);
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

var readData = function(arr) {
    var file        = fs.createReadStream(path.join(fileDir, arr[3]));

    file.on('data', function(chunk) { data+=chunk; });

    file.on('end', function(){
        makeTable(data, arr, function(arr, table){
        		composeEmailHTML(arr, table);
        });
    });
};

var makeTable = function(csv, arr, cb) {
    var lines = csv.replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .split(/[\n\r]/)
        .map(function(line) { return line.split(','); })
        .map(function(row) {return '\t\t<tr><td>' + row[0] + '</td><td>' + row[1] + '</td></tr>';});
     
    var table = '<table>\n\t<thead>\n'      + lines[0] +
                '\n\t</thead>\n\t<tbody>\n' + lines.slice(1).join('\n') +
                '\t</tbody>\n</table>';

    cb(arr, table);
};


var composeEmailHTML = function(arr, table){
	var text = arr[0], to = arr[1], subject = arr[2], attachment = arr[3];
	var message = {
		text: text,
		from: 'John Skilbeck jskilbeck@yapstone.com',
		to: 	to,
		subject: subject,
		attachment: [
			{ data: '<html><body><p>Automated Email</p><br />'+table+'</body></html>', alternative:true},
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





exports.email = email;


