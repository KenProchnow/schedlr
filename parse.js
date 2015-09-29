var 
	fs 	= require('fs')				
	, path = require('path')
	, data = ''
	, fileDir = './../sql'
	;

var parseSQL = function(file, cb){ 
	parseFile(file, cb); 
};

var parseFile = function(file, cb){
	var sqlFile 		= fs.createReadStream(path.join(fileDir, file + '.sql'));

	sqlFile.on('data', function(chunk){ data+=chunk; });

	sqlFile.on('end', function() {
		cleanUp(data, cb);
	});

};

var cleanUp = function(sql,cb){
  sql.replace(/(\r\n|\n|\r)/gm," "); 	// remove newlines
  sql.replace(/\s+/g, ' '); 					// excess white space

  cb(sql);
};

exports.parseSQL = parseSQL;