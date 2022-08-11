USE master
GO

DECLARE 
		    @DatabaseOLDName			          sysname  = 'test',										
        @DatabaseNewName			          sysname  = 'test1',										
        @PrimaryDataFileName		        sysname  = 'test',									
		    @SecDataFileName                sysname  =  NULL,
        @DatabaseLogFileName		        sysname  = 'test_log',								
		    @PrimaryDataFileCreatePath      sysname  = 'D:\MISC\Bkp\testdata.mdf',			
        @SecDataFileCreatePath		      sysname  = NULL,									
        @SecDataFileCreatePath1		      sysname  = NULL,									
        @DatabaseLogFileCreatePath      sysname  = 'D:\MISC\Bkp\test_log.ldf',		
        @PITRDateTime				            datetime = '2022-08-11T20:44:11';

DECLARE @command					              nvarchar(MAX),
        @OldPhysicalPathName		        nvarchar(MAX),
        @FullBackupDateTime			        datetime,
        @DiffBackupDateTime			        datetime,
        @LogBackupDateTime			        datetime,
        @message					              nvarchar(MAX);

SET @command = N'RESTORE DATABASE @DatabaseNewName FROM DISK = @OldPhysicalPathName WITH FILE = 1, NORECOVERY, NOUNLOAD, REPLACE, STATS = 5, STOPAT = @PITRDateTime,
     MOVE N''' + @PrimaryDataFileName + N''' TO N''' + @PrimaryDataFileCreatePath + N''','
           + COALESCE('
     MOVE N''' + @SecDataFileName + ''' TO N''' + @SecDataFileCreatePath + ''',', '')
           + N'
     MOVE N''' + @DatabaseLogFileName + N''' TO N''' + @DatabaseLogFileCreatePath + N''';';

SELECT     TOP (1) @OldPhysicalPathName = bmf.physical_device_name,@FullBackupDateTime = bs.backup_start_date
FROM       msdb.dbo.backupset AS bs INNER JOIN msdb.dbo.backupmediafamily AS bmf ON  bmf.media_set_id = bs.media_set_id
WHERE      bs.database_name = @DatabaseOLDName AND  bs.type= 'D' AND  bs.backup_start_date < @PITRDateTime
ORDER BY   bs.backup_start_date DESC;

SET @message = N'Starting restore of full backup file '+ @OldPhysicalPathName + N', taken ' + CONVERT(nvarchar(30), @FullBackupDateTime, 120);

RAISERROR(@message, 0, 1) WITH NOWAIT;

EXEC sys.sp_executesql @command,
                       N'@DatabaseNewName sysname, @OldPhysicalPathName nvarchar(260), @PITRDateTime datetime',
                       @DatabaseNewName,
                       @OldPhysicalPathName,
                       @PITRDateTime;


-- Step 2: Find last differential backup before recovery point, then restore it
SET @command = N'RESTORE DATABASE @DatabaseNewName FROM DISK = @OldPhysicalPathName WITH FILE = 1, NORECOVERY, NOUNLOAD, REPLACE, STATS = 5, STOPAT = @PITRDateTime;';

SELECT     TOP (1) @OldPhysicalPathName = bmf.physical_device_name,@DiffBackupDateTime = bs.backup_start_date
FROM       msdb.dbo.backupset   AS bs INNER JOIN msdb.dbo.backupmediafamily AS bmf ON  bmf.media_set_id = bs.media_set_id
WHERE      bs.database_name = @DatabaseOLDName AND  bs.type  = 'I' AND  bs.backup_start_date >= @FullBackupDateTime AND  bs.backup_start_date< @PITRDateTime
ORDER BY   bs.backup_start_date DESC;

IF @@ROWCOUNT > 0
BEGIN;
    SET @message = N'Starting restore of differential backup file ' + @OldPhysicalPathName + N', taken ' + CONVERT(nvarchar(30), @DiffBackupDateTime, 120);

    RAISERROR(@message, 0, 1) WITH NOWAIT;

EXEC sys.sp_executesql @command,
                       N'@DatabaseNewName sysname, @OldPhysicalPathName nvarchar(260), @PITRDateTime datetime',
                       @DatabaseNewName,
                       @OldPhysicalPathName,
                       @PITRDateTime;
END;

SET @command = N'RESTORE LOG @DatabaseNewName
FROM DISK = @OldPhysicalPathName
WITH FILE = 1, NORECOVERY, NOUNLOAD, REPLACE, STATS = 5, STOPAT = @PITRDateTime;';

DECLARE c CURSOR LOCAL FAST_FORWARD READ_ONLY TYPE_WARNING FOR
SELECT     bmf.physical_device_name,
           bs.backup_start_date
FROM       msdb.dbo.backupset         AS bs
INNER JOIN msdb.dbo.backupmediafamily AS bmf
   ON      bmf.media_set_id = bs.media_set_id
WHERE      bs.database_name = @DatabaseOLDName
AND        bs.type                 = 'L'
AND        bs.backup_start_date    >= COALESCE(@DiffBackupDateTime, @FullBackupDateTime)
ORDER BY   bs.backup_start_date ASC;

OPEN c;

FETCH NEXT FROM c
INTO @OldPhysicalPathName,
     @LogBackupDateTime;

WHILE @@FETCH_STATUS = 0
BEGIN;
    SET @message = N'Starting restore of log backup file '
                   + @OldPhysicalPathName + N', taken '
                   + CONVERT(nvarchar(30), @LogBackupDateTime, 120);
    RAISERROR(@message, 0, 1) WITH NOWAIT;
    EXEC sys.sp_executesql @command,
                           N'@DatabaseNewName sysname, @OldPhysicalPathName nvarchar(260), @PITRDateTime datetime',
                           @DatabaseNewName,
                           @OldPhysicalPathName,
                           @PITRDateTime;

    IF @LogBackupDateTime >= @PITRDateTime
        BREAK;

    FETCH NEXT FROM c
    INTO @OldPhysicalPathName,
         @LogBackupDateTime;
END;

CLOSE c;
DEALLOCATE c;

SET @command = N'RESTORE DATABASE @DatabaseNewName
WITH RECOVERY;';

RAISERROR('Starting recovery', 0, 1) WITH NOWAIT;
EXEC sys.sp_executesql @command,
                       N'@DatabaseNewName sysname, @OldPhysicalPathName nvarchar(260), @PITRDateTime datetime',
                       @DatabaseNewName,
                       @OldPhysicalPathName,
                       @PITRDateTime;
GO
