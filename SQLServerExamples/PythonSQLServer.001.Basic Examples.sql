-- #########################################################################################################################################################
-- Running Python in SQL Server
-- #########################################################################################################################################################

-- Check if external script running is avaliable 
sp_configure 'external scripts enabled'

-- Print a value
EXEC sp_execute_external_script @language = N'Python', 
@script = N'print(3+4)'

-- Variables 
execute sp_execute_external_script 
@language = N'Python', 
@script = N'
a = 1
b = 2
c = a/b
d = a*b
print(c, d)
'

-- #########################################################################################################################################################
-- 
-- #########################################################################################################################################################

execute sp_execute_external_script 
@language = N'Python', 
@script = N'
import pandas as pd
a = 1
b = 2
c = a/b
d = a*b
s = pandas.Series([c,d])
print(s)
df = pd.DataFrame(s)
OutputDataSet = df
'
WITH RESULT SETS (( ResultValue float ))

-- #########################################################################################################################################################
-- 
-- #########################################################################################################################################################