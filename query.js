var 
	fs 					= require('fs'),
	path 				= require('path'),
	sql 				= require('mssql'),
	fileDir 		= 'SQL Files',
	outDir 			= 'CSVs',
	file 				= 'query2',
	csv 				= require('fast-csv'),
	// csvStream  	= cs
	config 			= require('./lib/config/config.js'),
	// csvStream 	= csv.c;reateWriteStream({headers: true}),
	outFile			= fs.createWriteStream(path.join(outDir, file + '.csv')),
	data 				= '';
	sqlFile 		= fs.createReadStream(path.join(fileDir, file + '.sql'))
	;

sqlFile.on('data', function(chunk){ data+=chunk; });

sqlFile.on('end', function() {
	runQueryFromFile(data);
});

var runQueryFromFile = function(sql){
    sql.replace(/(\r\n|\n|\r)/gm," "); // remove newlines
    sql.replace(/\s+/g, ' '); // excess white space
    runQuery(sql);
};

var runQuery = function(statement) {
	var connection 	= new sql.Connection(config, function(err) {
		var r = new sql.Request(connection);
		r.query(statement, function(err, results){
			// console.log(results);
			saveCSV2(results);
		});
	});

	connection.on('error', function(err){
		console.log(err);
	});
};


var saveCSV = function(data) {
	// console.log(data);

	csv.stringify(data, function(err,data){
		outFile.write(data);
		outFile.end();
	});


};

var saveCSV2 = function(data) {
	csv.write(data, {headers: true}).pipe(outFile);
};










