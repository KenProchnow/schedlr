var 
	fs = require('fs')		
	, path = require('path')
	, csv = require('fast-csv')
	, mssql = require('mssql')
	, db_config = require('./lib/config/database.js')
	, outDir = './../csv'
	;

var executeQuery = function(sql, file, cb) {
	runQuery(sql, file, cb);
};

var runQuery = function(sql, file, cb) {
	var connection 	= new mssql.Connection(db_config, function(err) {
		if (err) console.log(err);
		var r = new mssql.Request(connection);
		// if (file === 'daily_tpv') { r.output('Date', sql.Date); }
		r.input('Date', mssql.Date);
		r.output('Date', mssql.Date);
		r.query(sql, function(err, results){
			if (err) console.log(err);
			console.log(results);

			saveCSV(results, file, cb);
		});
	});
};

var saveCSV = function(data, file, cb) {
	var outFile 		= path.join(outDir, file + '.csv');

	csv.writeToPath(outFile, data, {headers: true})
	.on('finish', function(){
		cb(file);
	});
};

exports.executeQuery = executeQuery;