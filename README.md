# SQLServerPointInTimeRestore

prerequisite : 

1.As best practise database needs to configured with Full , Differential and Log Backup

2.When PITR restore alternative drive needs to have enough space for restore the backup 

Passing Parameter Values : 

@DatabaseOLDName              - Corrupted/Data Loss Database Name

@DatabaseNewName							- The New Database Name you want to restore

@PrimaryDataFileName					- Primary Data File name of Corrupted/Data Loss Database 

@SecDataFileName              - If we have secondary data file , mention the name 

@DatabaseLogFileName					- Primary Log File name of Corrupted/Data Loss Database 

@PrimaryDataFileCreatePath 	  - The Path of New Restoring Database Primary Data File Need to Created ( Mention with testdata.mdf )

@SecDataFileCreatePath				- The Path of New Restoring Database Secondary Data File Need to Created ( Mention with testsecdata.ndf )	

@SecDataFileCreatePath1				- The Path of New Restoring Database Additional Secondary Data File Need to Created ( Mention with testsecdata.ndf )			

@DatabaseLogFileCreatePath  	- The Path of New Restoring Database Log File Need to Created ( Mention with testlog.ldf )

@PITRDateTime				          - Mention date and time of before hours/Minutes/Seconds/Milliseconds SQL Database Needs to Created ( Format : '2022-08-11T20:44:11' )
