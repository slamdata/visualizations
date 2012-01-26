//** QUERY
ReportGrid.query
	.intersectSeries({
		path : "/query/test",
		event : "impression",
		start : "5 hours ago",
		periodicity : "hour",
		properties : [{
			property : "browser", top : 2
		}, {
			property : "env", bottom : 5
		}]
	})