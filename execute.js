var 
	fs 					= require('fs'), 				path = require('path'),
	csv 				= require('fast-csv'), 	config 			= require('./lib/config/database.js'),
	sql 				= require('mssql'),			data 				= '';
	file 				= 'daily_tpv',							fileDir 		= 'SQL Files', 			
	outDir 			= 'CSVs', 							//outFile			= fs.createWriteStream(path.join(outDir, file + '.csv')),
	sqlFile 		= fs.createReadStream(path.join(fileDir, file + '.sql')),
	e				= require('./email.js')
	;

sqlFile.on('data', function(chunk){ data+=chunk; });

sqlFile.on('end', function() {
	cleanUp(data);
});

var cleanUp = function(sql){
  sql.replace(/(\r\n|\n|\r)/gm," "); 	// remove newlines
  sql.replace(/\s+/g, ' '); 					// excess white space
  runQuery(sql);
};

var runQuery = function(statement) {
	var connection 	= new sql.Connection(config, function(err) {
		var r = new sql.Request(connection);
		r.query(statement, function(err, results){
			saveCSV2(results);
		});
	});

	connection.on('error', function(err){
		console.log(err);
	});
};

var saveCSV = function(data) {
	csv.stringify(data, function(err,data){
		outFile.write(data);
		outFile.end();
	});
};

var saveCSV2 = function(data) {
	csv.writeToPath('CSVs/daily_tpv.csv', data, {headers: true}) //.pipe(outFile)
	.on('finish', function(){
		e.email([
			'You are receiving an automated message',
			['jskilbeck@yapstone.com','john.skilbeck@gmail.com'],
			'Daily TPV numbers',
			file+'.csv'
		]);
	});


};





