var 
	fs 					= require('fs'), 				
	path 				= require('path'),
	csv 				= require('fast-csv'), 
	mssql 			= require('mssql'),		
	db_config 	= require('./lib/config/database.js'),		
	outDir 			= 'CSVs',
	e						= require('./email.js'),
	distro 			= require('./emailDistributionList/distributionList.js')
	;

var executeQuery = function(sql, file) {
	runQuery(sql, file);
};


var runQuery = function(sql, file) {
	var connection 	= new mssql.Connection(db_config, function(err) {
		if (err) console.log(err);
		var r = new mssql.Request(connection);
		r.query(sql, function(err, results){
			if (err) console.log(err);
			saveCSV(results, file);
		});
	});

	connection.on('error', function(err){
		console.log(err);
	});
};

var saveCSV = function(data, file) {
	var outFile 		= path.join(outDir, file + '.csv');

	csv.writeToPath(outFile, data, {headers: true})
	.on('finish', function(){
		// console.log(data);
		emailData(file);
	});
};

var emailData = function(file) {
	e.email([
		'You are receiving an automated message',
		distro[file],
		'Daily TPV numbers',
		file+'.csv'
	]);
};


exports.executeQuery = executeQuery;

