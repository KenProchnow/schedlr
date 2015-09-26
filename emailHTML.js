var 
	email				= require('emailjs'),	
	emailconfig = require('./config/email.js'),
	server 			= email.server.connect(emailconfig),
	distro 			= './../emailDistributionList/distributionList.js',
	fs = require('fs'),
	path = require('path'),
	data = '',
	fileDir 		= 'CSVs'
	;

var email = function(file){
	readData(file);
	// generateTable(file);
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
	    table.push("<tr><td>"+ lines[i].split(",").join("</td><td>")+ "</td></tr>");
	}
	table = "<table>" + table.join("") + "</table>";

	cb(table, file);

    // var lines = data.replace(/&/g, '&amp;')
    //     .replace(/</g, '&lt;')
    //     .replace(/>/g, '&gt;')
    //     .replace(/"/g, '&quot;')
    //     .split(/[\n\r]/)
    //     .map(function(line) { return line.split(','); })
    //     .map(function(row) {return '\t\t<tr><td>' + row[0] + '</td><td>' + row[1] + '</td></tr>';});
     
    // var table = '<table>\n\t<thead>\n'      + lines[0] +
    //             '\n\t</thead>\n\t<tbody>\n' + lines.slice(1).join('\n') +
    //             '\t</tbody>\n</table>';

   // cb(table);
};


var composeEmailHTML = function(table, file){
	var arr = ['You are receiving an automated message', // body
		distro[file], // distro
		'Daily TPV numbers', // subject
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
			{ path: 'CSVs/'+attachment, type: 'text/csv', name: attachment	}
		]
	};

	console.log(message);

	sendEmail(message);
};




var sendEmail = function(message){
	server.send(message, function(err, message){
		console.log(err || message);
	});
};

exports.email = email;


