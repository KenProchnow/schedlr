var 
	fs = require('fs')		
	, path = require('path')
	, csv = require('fast-csv')
	, mssql = require('mssql')
	, db_config = require('./lib/config/database.js')
	, f = require('./lib/format.js')
	, outDir = './csv'
	;

var executeQuery = function(sql, folder, file, cb) {
	runQuery(sql, folder, file, cb);
};

var runQuery = function(sql, folder, file, cb) {
	var connection 	= new mssql.Connection(db_config, function(err) {
		if (err) console.log(err);
		var r = new mssql.Request(connection);
		r.query(sql, function(err, results){
			if (err) console.log(err);
			transform(results, folder, file, cb);
		});
	});
};

var transform = function(data, folder, file, cb){
	for(var record in data){ if (data.hasOwnProperty(record)){ // (records as objects)data[record]
		for(var item in data[record]){ if(data[record].hasOwnProperty(item)){ // (key)item : (values)data[record][item] 
			if (f.isDate(data[record][item])) { // format date
				data[record][item] = f.formatDate(data[record][item]);
			}

			if ( ( !f.isDateColumn(item) ) && ( !f.isExcludeColumn(item) ) && ( !isNaN(parseFloat(data[record][item])) ) && ( !f.hasPercentString(data[record][item]) ) ) { // format numbers
				data[record][item] = f.formatNumber(parseInt(data[record][item]));
			}	}
		}	}
	}
	saveCSV(data, folder, file, cb);
};

var saveCSV = function(data, folder, file, cb) {
	var outFile 		= path.join(outDir, folder, file + '.csv');

	csv.writeToPath(outFile, data, {headers: true})
	.on('finish', function(){
		cb(data, folder, file);
	});
};


exports.executeQuery = executeQuery;