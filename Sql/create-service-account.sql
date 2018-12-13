DECLARE @UserSQL AS nvarchar(max)
DECLARE @GrantSQL AS nvarchar(max)

-- Create user if it does not exist
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE NAME = @UserName) BEGIN
    SET @UserSQL = 'CREATE USER [' + @UserName + '] WITH PASSWORD = ''' + @Password + ''''
    EXECUTE(@UserSQL)
END

-- Add user to db roles
EXEC sp_addrolemember 'db_datareader', @UserName
EXEC sp_addrolemember 'db_datawriter', @UserName

-- Add Grants
SET @GrantSQL = 'GRANT EXECUTE TO [' + @UserName + ']'
EXEC(@GrantSQL)

-- Reset \ Rotate user password on each run
IF EXISTS (SELECT name FROM sys.database_principals WHERE NAME = @UserName) BEGIN
SET @UserSQL = 'ALTER USER [' + @UserName +']  WITH PASSWORD = ''' + @Password + ''''
EXECUTE(@UserSQL)
END

