var 
	sql 			= require('mssql'),
	config 		= require('config.js')
	;

var connection 	= new sql.Connection(config, function(err) {
	var r = new sql.Request(connection);

	r.query('select 1 as number', function(err, results){
		console.log(results);
	});
});

connection.on('error', function(err){
	console.log(err);
});